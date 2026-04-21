<?php

namespace App\Http\Controllers;

use App\Models\Document;
use App\Models\Hospital;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * PdfIngestionController
 *
 * Handles automated ingestion of ER reports (PDF) exported from Hipocrate.
 *
 * Two ingestion methods are supported:
 *
 *  1. HTTP push  — Hipocrate (or a middleware script) POSTs the PDF directly.
 *     POST /api/ingest/pdf
 *
 *  2. Folder poll — A cron / artisan command calls pollFolder() to scan
 *     a watched directory and ingest any PDFs placed there.
 *     POST /api/ingest/poll   (manual trigger, protected by API key)
 *
 * CNP extraction order of precedence:
 *  a) Explicit `cnp` field in the request body
 *  b) Filename pattern: anything matching 13 consecutive digits
 *  c) PDF text scan: first 13-digit sequence in the first 4 KB of text
 */
class PdfIngestionController extends Controller
{
    // ── HTTP push endpoint ────────────────────────────────────────────────────

    /**
     * POST /api/ingest/pdf
     *
     * Expected payload (multipart/form-data):
     *   file        – the PDF file
     *   cnp         – (optional) patient CNP, 13 digits
     *   hospital_id – (optional) hospital to associate the patient with
     *   document_name – (optional) display name for the document
     *
     * Authentication: Bearer token belonging to a doctor / hospital_admin /
     * global_admin OR the static INGEST_API_KEY set in .env.
     */
    public function ingest(Request $request)
    {
        if (! $this->authorised($request)) {
            return response(['message' => 'Acces neautorizat'], 401);
        }

        $request->validate([
            'file'          => 'required|file|mimes:pdf|max:51200', // 50 MB
            'cnp'           => 'nullable|string|size:13',
            'hospital_id'   => 'nullable|exists:hospitals,id',
            'document_name' => 'nullable|string|max:255',
        ]);

        $file = $request->file('file');
        $originalName = $file->getClientOriginalName();

        // 1. Resolve CNP
        $cnp = $this->resolveCnp(
            explicit: $request->input('cnp'),
            filename: $originalName,
            pdfBytes: $file->get(),
        );

        if (! $cnp) {
            return response([
                'success' => false,
                'message' => 'CNP-ul pacientului nu a putut fi identificat. '
                    . 'Trimite câmpul `cnp` explicit sau asigură-te că '
                    . 'numele fișierului sau conținutul PDF conține 13 cifre consecutive.',
            ], 422);
        }

        // 2. Find or create patient
        $hospitalId = $request->input('hospital_id')
            ?? $this->inferHospitalId($request);

        $patient = $this->findOrCreatePatient($cnp, $hospitalId, $originalName);

        // 3. Store the PDF
        $storagePath = $file->store('documents/' . $patient->id, 'public');
        $docName = $request->input('document_name')
            ?? $this->buildDocumentName($originalName);

        $document = Document::create([
            'user_id' => $patient->id,
            'name'    => $docName,
            'path'    => $storagePath,
        ]);

        return response([
            'success'  => true,
            'message'  => 'Document ingerat cu succes',
            'patient'  => [
                'id'      => $patient->id,
                'name'    => $patient->name,
                'cnp'     => $patient->cnp_pacient,
                'created' => $patient->wasRecentlyCreated,
            ],
            'document' => [
                'id'   => $document->id,
                'name' => $document->name,
                'url'  => url('storage/' . $storagePath),
            ],
        ], 201);
    }

    // ── Folder poll endpoint ──────────────────────────────────────────────────

    /**
     * POST /api/ingest/poll
     *
     * Scans the watched folder (INGEST_WATCH_DIR in .env, default:
     * storage/app/ingest/watch) for PDF files and ingests each one.
     * Successfully processed files are moved to storage/app/ingest/processed/.
     * Files that fail are moved to storage/app/ingest/failed/.
     *
     * Returns a summary of what was processed.
     */
    public function pollFolder(Request $request)
    {
        if (! $this->authorisedByApiKey($request)) {
            return response(['message' => 'API key invalid'], 401);
        }

        $watchDir     = config('ingest.watch_dir',
            storage_path('app/ingest/watch'));
        $processedDir = config('ingest.processed_dir',
            storage_path('app/ingest/processed'));
        $failedDir    = config('ingest.failed_dir',
            storage_path('app/ingest/failed'));

        foreach ([$watchDir, $processedDir, $failedDir] as $dir) {
            if (! is_dir($dir)) {
                mkdir($dir, 0755, true);
            }
        }

        $results   = ['processed' => [], 'failed' => [], 'skipped' => []];
        $pdfFiles  = glob($watchDir . DIRECTORY_SEPARATOR . '*.pdf') ?: [];
        $pdfFiles  = array_merge(
            $pdfFiles,
            glob($watchDir . DIRECTORY_SEPARATOR . '*.PDF') ?: []
        );

        foreach ($pdfFiles as $filePath) {
            $filename = basename($filePath);

            try {
                $pdfBytes = file_get_contents($filePath);
                $cnp      = $this->resolveCnp(
                    explicit: null,
                    filename: $filename,
                    pdfBytes: $pdfBytes,
                );

                if (! $cnp) {
                    rename($filePath, $failedDir . DIRECTORY_SEPARATOR . $filename);
                    $results['failed'][] = [
                        'file'   => $filename,
                        'reason' => 'CNP nu a putut fi extras',
                    ];
                    continue;
                }

                // Determine hospital from request context or leave null
                $patient = $this->findOrCreatePatient($cnp, null, $filename);

                // Store the file
                $relativePath = 'documents/' . $patient->id . '/' . Str::uuid() . '_' . $filename;
                Storage::disk('public')->put($relativePath, $pdfBytes);

                Document::create([
                    'user_id' => $patient->id,
                    'name'    => $this->buildDocumentName($filename),
                    'path'    => $relativePath,
                ]);

                rename($filePath, $processedDir . DIRECTORY_SEPARATOR . $filename);

                $results['processed'][] = [
                    'file'           => $filename,
                    'patient_id'     => $patient->id,
                    'patient_name'   => $patient->name,
                    'patient_new'    => $patient->wasRecentlyCreated,
                ];
            } catch (\Throwable $e) {
                rename($filePath, $failedDir . DIRECTORY_SEPARATOR . $filename);
                $results['failed'][] = [
                    'file'   => $filename,
                    'reason' => $e->getMessage(),
                ];
            }
        }

        return response([
            'success' => true,
            'summary' => [
                'processed' => count($results['processed']),
                'failed'    => count($results['failed']),
                'skipped'   => count($results['skipped']),
            ],
            'details' => $results,
        ], 200);
    }

    // ── Status / health ───────────────────────────────────────────────────────

    /**
     * GET /api/ingest/status
     * Returns counts and recent ingestion stats. No auth required (public health check).
     */
    public function status()
    {
        $watchDir = config('ingest.watch_dir', storage_path('app/ingest/watch'));
        $pending  = is_dir($watchDir)
            ? count(glob($watchDir . DIRECTORY_SEPARATOR . '*.{pdf,PDF}', GLOB_BRACE) ?: [])
            : 0;

        return response([
            'pending_files'   => $pending,
            'total_documents' => Document::count(),
            'total_patients'  => User::where('role', 'patient')->count(),
            'watch_dir'       => $watchDir,
        ]);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Extract CNP from three sources, in priority order.
     */
    private function resolveCnp(?string $explicit, string $filename, string $pdfBytes): ?string
    {
        // a) Explicit field
        if ($explicit && preg_match('/^\d{13}$/', $explicit)) {
            return $explicit;
        }

        // b) Filename: e.g. "UPU_1234567890123_2024.pdf" or "1234567890123.pdf"
        if (preg_match('/(\d{13})/', $filename, $m)) {
            return $m[1];
        }

        // c) PDF text scan — extract printable chars from the first 4 KB
        //    Real implementation would use a PDF library; this covers text-layer PDFs.
        $sample = substr($pdfBytes, 0, 4096);
        $text   = preg_replace('/[^\x20-\x7E]/', ' ', $sample); // keep printable ASCII
        if (preg_match('/\b(\d{13})\b/', $text, $m)) {
            return $m[1];
        }

        // d) Extended scan of first 50 KB for richer PDFs
        if (strlen($pdfBytes) > 4096) {
            $extended = substr($pdfBytes, 0, 51200);
            $text2    = preg_replace('/[^\x20-\x7E]/', ' ', $extended);
            if (preg_match('/\b(\d{13})\b/', $text2, $m)) {
                return $m[1];
            }
        }

        return null;
    }

    /**
     * Find existing patient by CNP or create a new one.
     */
    private function findOrCreatePatient(string $cnp, ?int $hospitalId, string $filename): User
    {
        $patient = User::where('cnp_pacient', $cnp)
            ->where('role', 'patient')
            ->first();

        if ($patient) {
            // Update hospital if we now know it and patient doesn't have one
            if ($hospitalId && ! $patient->hospital_id) {
                $patient->update(['hospital_id' => $hospitalId]);
            }
            return $patient;
        }

        // Generate a readable placeholder name from CNP
        // Real name will be set when the patient registers / is matched
        $placeholderName = 'Pacient ' . substr($cnp, 0, 4) . '****' . substr($cnp, -3);

        return User::create([
            'name'        => $placeholderName,
            'email'       => 'pacient.' . $cnp . '@hipocrate.internal',
            'password'    => bcrypt(Str::random(32)), // random, unusable password
            'role'        => 'patient',
            'cnp_pacient' => $cnp,
            'hospital_id' => $hospitalId,
            'is_active'   => true,
        ]);
    }

    /**
     * Try to infer hospital_id from the authenticated user.
     */
    private function inferHospitalId(Request $request): ?int
    {
        $user = $request->user();
        return $user?->hospital_id;
    }

    /**
     * Build a human-readable document name from the raw filename.
     * "UPU_1234567890123_2024-01-15.pdf" → "Raport UPU 2024-01-15"
     */
    private function buildDocumentName(string $filename): string
    {
        $base = pathinfo($filename, PATHINFO_FILENAME);

        // Remove CNP to keep it out of display names
        $base = preg_replace('/\d{13}/', '', $base);

        // Replace underscores/dashes with spaces and trim
        $base = trim(preg_replace('/[-_]+/', ' ', $base));

        // Prefix if blank after cleaning
        if (empty($base)) {
            return 'Raport UPU ' . now()->format('Y-m-d H:i');
        }

        // Capitalise first word
        return ucfirst(strtolower($base));
    }

    /**
     * Check whether the request is authorised:
     * - Bearer token of a doctor / admin, OR
     * - Static API key in X-Ingest-Key header
     */
    private function authorised(Request $request): bool
    {
        // Static key check first (used by Hipocrate middleware)
        if ($this->authorisedByApiKey($request)) {
            return true;
        }

        // Sanctum-authenticated user with the right role
        $user = $request->user();
        if ($user && in_array($user->role, ['global_admin', 'hospital_admin', 'doctor'])) {
            return true;
        }

        return false;
    }

    private function authorisedByApiKey(Request $request): bool
    {
        $key = config('ingest.api_key');
        if (! $key) {
            return false;
        }
        return $request->header('X-Ingest-Key') === $key
            || $request->input('api_key') === $key;
    }
}