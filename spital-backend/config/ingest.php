<?php

return [

    /*
    |--------------------------------------------------------------------------
    | PDF Ingestion — Watch Directory
    |--------------------------------------------------------------------------
    |
    | When using the folder-poll mode, place exported PDFs from Hipocrate here.
    | The artisan command `php artisan ingest:poll` (or the API endpoint
    | POST /api/ingest/poll) will pick them up automatically.
    |
    */

    'watch_dir' => env('INGEST_WATCH_DIR', storage_path('app/ingest/watch')),

    'processed_dir' => env('INGEST_PROCESSED_DIR', storage_path('app/ingest/processed')),

    'failed_dir' => env('INGEST_FAILED_DIR', storage_path('app/ingest/failed')),

    /*
    |--------------------------------------------------------------------------
    | Static API Key
    |--------------------------------------------------------------------------
    |
    | Set INGEST_API_KEY in .env to allow Hipocrate or an external middleware
    | to push PDFs without a Sanctum token.  Keep this secret.
    |
    | Example .env entry:
    |   INGEST_API_KEY=super-secret-random-key-64-chars
    |
    */

    'api_key' => env('INGEST_API_KEY'),

];