<?php

namespace App\Console\Commands;

use App\Http\Controllers\PdfIngestionController;
use Illuminate\Console\Command;
use Illuminate\Http\Request;

class IngestPoll extends Command
{
    protected $signature = 'ingest:poll
                            {--dir= : Override the watch directory for this run}';

    protected $description = 'Scan the PDF watch folder and ingest any new Hipocrate reports';

    public function handle(): int
    {
        $dir = $this->option('dir');
        if ($dir) {
            config(['ingest.watch_dir' => $dir]);
        }

        $watchDir = config('ingest.watch_dir', storage_path('app/ingest/watch'));

        if (! is_dir($watchDir)) {
            $this->warn("Watch directory does not exist: {$watchDir}");
            $this->info("Creating it now...");
            mkdir($watchDir, 0755, true);
            $this->info("Directory created. Place PDF files there and re-run.");
            return 0;
        }

        $pdfs = glob($watchDir . DIRECTORY_SEPARATOR . '*.{pdf,PDF}', GLOB_BRACE) ?: [];

        if (empty($pdfs)) {
            $this->info("No PDF files found in {$watchDir}");
            return 0;
        }

        $this->info("Found " . count($pdfs) . " PDF(s) to process...");

        // Build a fake Request with the static API key so the controller
        // authorisation passes without needing a database user.
        $fakeRequest = Request::create('/api/ingest/poll', 'POST');
        $fakeRequest->headers->set('X-Ingest-Key', config('ingest.api_key', 'cli'));

        $controller = new PdfIngestionController();
        $response   = $controller->pollFolder($fakeRequest);
        $data       = json_decode($response->getContent(), true);

        foreach ($data['details']['processed'] ?? [] as $item) {
            $flag = $item['patient_new'] ? ' [NEW PATIENT]' : '';
            $this->info("  ✓ {$item['file']} → {$item['patient_name']}{$flag}");
        }

        foreach ($data['details']['failed'] ?? [] as $item) {
            $this->error("  ✗ {$item['file']} — {$item['reason']}");
        }

        $s = $data['summary'];
        $this->newLine();
        $this->info("Done. Processed: {$s['processed']}, Failed: {$s['failed']}");

        return 0;
    }
}