{- |
Module      : Cardano.Mithril.Import
Description : Import UTxO data from Mithril snapshots

This module provides the bridge between Mithril snapshots and a
database. It orchestrates the full bootstrap process:

1. Fetch latest snapshot metadata from Mithril aggregator
2. Download and verify snapshot via HTTP
3. Extract UTxO set from Cardano ledger state files
4. Stream UTxOs into database via caller-provided insert function
5. Return the slot number for chain sync continuation
-}
module Cardano.Mithril.Import
    ( -- * Import operations
      importFromMithril
    , ImportResult (..)

      -- * Tracing
    , ImportTrace (..)
    , renderImportTrace
    )
where

import Cardano.Mithril.Client
    ( MithrilConfig (..)
    , MithrilError
    , MithrilTrace (..)
    , SnapshotMetadata (..)
    , downloadSnapshotHttp
    , fetchLatestSnapshot
    , renderMithrilError
    , renderMithrilTrace
    )
import Cardano.Mithril.Extraction
    ( ExtractionError
    , ExtractionTrace
    , extractUTxOsFromSnapshot
    , renderExtractionError
    , renderExtractionTrace
    )
import Cardano.Mithril.Streaming
    ( StreamTrace
    , defaultStreamConfig
    , renderStreamTrace
    , streamToCSMT
    )
import Control.Tracer (Tracer, contramap, traceWith)
import Data.ByteString.Lazy (ByteString)
import Data.Tracer.TraceWith (trace, tracer, pattern TraceWith)
import Data.Word (Word64)

-- | Result of Mithril import operation
data ImportResult
    = ImportSuccess
        { importCount :: Word64
        -- ^ Number of UTxOs imported
        , importDbPath :: FilePath
        -- ^ Path to the immutable DB
        , importSlot :: Word64
        -- ^ Slot from ledger state for skip-until logic
        }
    | -- | Import failed with Mithril error
      ImportFailed MithrilError
    | -- | Import failed during extraction
      ImportExtractionFailed ExtractionError

-- | Trace events during import
data ImportTrace
    = -- | Starting Mithril import process
      ImportStarting
    | -- | Mithril client operation
      ImportMithril MithrilTrace
    | -- | Extracting UTxO from immutable DB at path
      ImportExtractingUTxO FilePath
    | -- | Extraction trace event
      ImportExtraction ExtractionTrace
    | -- | Streaming trace event
      ImportStreaming StreamTrace
    | -- | Progress: current count, total estimated
      ImportProgress Word64 Word64
    | -- | Import complete: total UTxOs imported
      ImportComplete Word64
    | -- | Error during import
      ImportError MithrilError
    | -- | Extraction error
      ImportExtractionError ExtractionError
    deriving (Show)

-- | Render trace for logging
renderImportTrace :: ImportTrace -> String
renderImportTrace ImportStarting =
    "Starting Mithril bootstrap import..."
renderImportTrace (ImportMithril mt) =
    renderMithrilTrace mt
renderImportTrace (ImportExtractingUTxO path) =
    "Extracting UTxO set from ledger state: " <> path
renderImportTrace (ImportExtraction et) =
    renderExtractionTrace et
renderImportTrace (ImportStreaming st) =
    renderStreamTrace st
renderImportTrace (ImportProgress current total) =
    "Import progress: "
        <> show current
        <> " / "
        <> show total
        <> " UTxOs"
renderImportTrace (ImportComplete count) =
    "Mithril import complete: "
        <> show count
        <> " UTxOs imported"
renderImportTrace (ImportError err) =
    "Mithril import error: " <> renderMithrilError err
renderImportTrace (ImportExtractionError err) =
    "Extraction error: " <> renderExtractionError err

{- | Import UTxO set from Mithril snapshot

This function orchestrates the full Mithril bootstrap process:

1. Fetches the latest snapshot metadata from the aggregator
2. Downloads and verifies the snapshot using HTTP
3. Extracts the UTxO set from the downloaded ledger state
4. Streams UTxOs into the database via the insert callback
5. Returns the slot number for chain sync to continue from

The @onBeforeDbWrite@ callback is invoked after download succeeds but
before streaming UTxOs into the database. This is the right moment to
set a bootstrap-in-progress marker: download failures won\'t leave a
stale marker that triggers unnecessary DB wipes on restart.
-}
importFromMithril
    :: Tracer IO ImportTrace
    -- ^ Tracer for progress logging
    -> MithrilConfig
    -- ^ Mithril client configuration
    -> IO ()
    -- ^ Action to run after download succeeds, before DB writes begin
    -> (ByteString -> ByteString -> IO ())
    -- ^ Insert a key-value pair into the database
    -> IO ImportResult
importFromMithril TraceWith{tracer, trace} config onBeforeDbWrite insertKV = do
    trace ImportStarting

    -- Step 1: Fetch latest snapshot metadata
    trace
        $ ImportMithril
        $ MithrilFetchingSnapshot (mithrilAggregatorUrl config)
    snapshotResult <- fetchLatestSnapshot config

    case snapshotResult of
        Left err -> do
            trace $ ImportError err
            pure $ ImportFailed err
        Right snapshot -> do
            let digest = snapshotDigest snapshot
                slot = snapshotBeaconSlot snapshot
                epoch = snapshotBeaconEpoch snapshot

            trace
                $ ImportMithril
                $ MithrilSnapshotFound digest slot epoch

            -- Step 2: Download and verify snapshot
            trace
                $ ImportMithril
                $ MithrilDownloading digest (mithrilDownloadDir config)

            downloadResult <-
                downloadSnapshotHttp
                    (contramap ImportMithril tracer)
                    config
                    snapshot

            case downloadResult of
                Left err -> do
                    traceWith tracer $ ImportError err
                    pure $ ImportFailed err
                Right dbPath -> do
                    traceWith tracer
                        $ ImportMithril
                        $ MithrilDownloadComplete dbPath

                    -- Mark bootstrap-in-progress now that we're about
                    -- to write to the DB. Download failures above won't
                    -- leave a stale marker.
                    onBeforeDbWrite

                    -- Step 3: Extract UTxO and import
                    traceWith tracer $ ImportExtractingUTxO dbPath

                    extractResult <-
                        extractUTxOsFromSnapshot
                            (contramap ImportExtraction tracer)
                            dbPath
                            ( streamToCSMT
                                (contramap ImportStreaming tracer)
                                defaultStreamConfig
                                insertKV
                            )

                    case extractResult of
                        Left err -> do
                            traceWith tracer $ ImportExtractionError err
                            pure $ ImportExtractionFailed err
                        Right (count, extractedSlot) -> do
                            traceWith tracer $ ImportComplete count

                            pure
                                ImportSuccess
                                    { importCount = count
                                    , importDbPath = dbPath
                                    , importSlot = extractedSlot
                                    }
