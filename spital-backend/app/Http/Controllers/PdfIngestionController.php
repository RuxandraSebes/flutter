<?php

namespace App\Http\Controllers;

use App\Models\Document;
use App\Models\IngestLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * PdfIngestionController
 *
 * Handles automated ingestion of ER reports (PDF) exported from Hipocrate.
 *
 * ── CNP extraction ───────────────────────────────────────────────────────────
 * CNP is extracted EXCLUSIVELY from the filename. PDF content is never scanned.
 *
 * Expected filename format:
 *   Buletin_Analize_<CNP13digits>_LastName_FirstName.pdf
 *   e.g. Buletin_Analize_1234567890123_Popescu_Ion.pdf
 *
 * The first unbroken sequence of 13 digits found in the filename is used as CNP.
 *
 * ── Two ingestion methods ────────────────────────────────────────────────────
 *  1. HTTP push  — POST /api/ingest/pdf   (multipart, authorized by API key or doctor/admin)
 *  2. Folder poll — POST /api/ingest/poll  (scans INGEST_WATCH_DIR, API key only)
 *                   Also triggered by: php artisan ingest:poll
 */
class PdfIngestionController extends Controller
{
    // ── HTTP push endpoint ────────────────────────────────────────────────────

    public function ingest(Request $request)
    {
        if (! $this->authorised($request)) {
            return response(['message' => 'Acces neautorizat'], 401);
        }

        $request->validate([
            'file'          => 'required|file|mimes:pdf|max:51200',
            'cnp'           => 'nullable|string|size:13',
            'hospital_id'   => 'nullable|exists:hospitals,id',
            'document_name' => 'nullable|string|max:255',
        ]);

        $file         = $request->file('file');
        $originalName = $file->getClientOriginalName();

        [$cnp, $cnpSource, $patientName] = $this->resolveCnpAndName(
            explicit: $request->input('cnp'),
            filename: $originalName,
        );

        $ingestedBy = $this->resolveIngestedBy($request);

        if (! $cnp) {
            IngestLog::create([
                'filename'    => $originalName,
                'status'      => 'no_cnp',
                'ingested_by' => $ingestedBy,
            ]);

            return response([
                'success' => false,
                'message' => 'CNP-ul pacientului nu a putut fi identificat. '
                    . 'Asigura-te ca numele fisierului respecta formatul: '
                    . 'Buletin_Analize_<CNP13cifre>_Nume_Prenume.pdf',
            ], 422);
        }

        $hospitalId = $request->input('hospital_id') ?? $this->inferHospitalId($request);

        $patient    = $this->findOrCreatePatient($cnp, $hospitalId, $patientName);
        $wasCreated = $patient->wasRecentlyCreated;

        $storagePath = $file->store('documents/' . $patient->id, 'public');
        $docName     = $request->input('document_name')
            ?? $this->buildDocumentName($originalName);

        $document = Document::create([
            'user_id' => $patient->id,
            'name'    => $docName,
            'path'    => $storagePath,
        ]);

        IngestLog::create([
            'filename'        => $originalName,
            'cnp_extracted'   => $cnp,
            'cnp_source'      => $cnpSource,
            'patient_id'      => $patient->id,
            'patient_created' => $wasCreated,
            'document_id'     => $document->id,
            'status'          => 'success',
            'ingested_by'     => $ingestedBy,
        ]);

        return response([
            'success'  => true,
            'message'  => 'Document ingerat cu succes',
            'patient'  => [
                'id'      => $patient->id,
                'name'    => $patient->name,
                'cnp'     => $patient->cnp_pacient,
                'created' => $wasCreated,
            ],
            'document' => [
                'id'   => $document->id,
                'name' => $document->name,
                'url'  => url('storage/' . $storagePath),
            ],
        ], 201);
    }

    // ── Folder poll endpoint ──────────────────────────────────────────────────

    public function pollFolder(Request $request)
    {
        if (! $this->authorisedByApiKey($request)) {
            return response(['message' => 'API key invalid'], 401);
        }

        $watchDir     = config('ingest.watch_dir',     storage_path('app/ingest/watch'));
        $processedDir = config('ingest.processed_dir', storage_path('app/ingest/processed'));
        $failedDir    = config('ingest.failed_dir',     storage_path('app/ingest/failed'));

        foreach ([$watchDir, $processedDir, $failedDir] as $dir) {
            if (! is_dir($dir)) {
                mkdir($dir, 0755, true);
            }
        }

        $results  = ['processed' => [], 'failed' => [], 'skipped' => []];
        $pdfFiles = array_merge(
            glob($watchDir . DIRECTORY_SEPARATOR . '*.pdf')  ?: [],
            glob($watchDir . DIRECTORY_SEPARATOR . '*.PDF')  ?: [],
        );

        foreach ($pdfFiles as $filePath) {
            $filename = basename($filePath);

            try {
                [$cnp, $cnpSource, $patientName] = $this->resolveCnpAndName(
                    explicit: null,
                    filename: $filename,
                );

                if (! $cnp) {
                    rename($filePath, $failedDir . DIRECTORY_SEPARATOR . $filename);

                    IngestLog::create([
                        'filename'    => $filename,
                        'status'      => 'no_cnp',
                        'ingested_by' => 'api_key',
                    ]);

                    $results['failed'][] = [
                        'file'   => $filename,
                        'reason' => 'CNP nu a putut fi extras din numele fisierului',
                    ];
                    continue;
                }

                $patient    = $this->findOrCreatePatient($cnp, null, $patientName);
                $wasCreated = $patient->wasRecentlyCreated;

                $pdfBytes     = file_get_contents($filePath);
                $relativePath = 'documents/' . $patient->id . '/' . Str::uuid() . '_' . $filename;
                Storage::disk('public')->put($relativePath, $pdfBytes);

                $document = Document::create([
                    'user_id' => $patient->id,
                    'name'    => $this->buildDocumentName($filename),
                    'path'    => $relativePath,
                ]);

                IngestLog::create([
                    'filename'        => $filename,
                    'cnp_extracted'   => $cnp,
                    'cnp_source'      => $cnpSource,
                    'patient_id'      => $patient->id,
                    'patient_created' => $wasCreated,
                    'document_id'     => $document->id,
                    'status'          => 'success',
                    'ingested_by'     => 'api_key',
                ]);

                rename($filePath, $processedDir . DIRECTORY_SEPARATOR . $filename);

                $results['processed'][] = [
                    'file'         => $filename,
                    'patient_id'   => $patient->id,
                    'patient_name' => $patient->name,
                    'patient_new'  => $wasCreated,
                ];

            } catch (\Throwable $e) {
                rename($filePath, $failedDir . DIRECTORY_SEPARATOR . $filename);

                IngestLog::create([
                    'filename'      => $filename,
                    'status'        => 'failed',
                    'error_message' => $e->getMessage(),
                    'ingested_by'   => 'api_key',
                ]);

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

    public function status()
    {
        $watchDir = config('ingest.watch_dir', storage_path('app/ingest/watch'));
        $pending  = is_dir($watchDir)
            ? count(glob($watchDir . DIRECTORY_SEPARATOR . '*.{pdf,PDF}', GLOB_BRACE) ?: [])
            : 0;

        $recentLogs = IngestLog::orderBy('created_at', 'desc')
            ->limit(10)
            ->get(['filename', 'status', 'cnp_source', 'patient_created', 'created_at']);

        return response([
            'pending_files'   => $pending,
            'total_documents' => Document::count(),
            'total_patients'  => User::where('role', 'patient')->count(),
            'watch_dir'       => $watchDir,
            'recent_ingests'  => $recentLogs,
        ]);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Extract CNP (and optionally patient name) from the filename ONLY.
     *
     * Supported formats:
     *   Buletin_Analize_1234567890123_Popescu_Ion.pdf   → CNP + name "Popescu Ion"
     *   UPU_1234567890123_2024-01-15.pdf                → CNP only
     *   1234567890123.pdf                               → CNP only
     *
     * Returns [cnp|null, source|null, patientName|null]
     */
    private function resolveCnpAndName(
        ?string $explicit,
        string  $filename,
    ): array {
        // a) Explicit CNP field in request body (API push)
        if ($explicit && preg_match('/^\d{13}$/', $explicit)) {
            // Try to extract name from filename even if CNP is explicit
            $name = $this->extractNameFromFilename($filename);
            return [$explicit, 'explicit', $name];
        }

        // b) Filename — extract first 13-digit sequence
        if (preg_match('/(\d{13})/', $filename, $m)) {
            $cnp  = $m[1];
            $name = $this->extractNameFromFilename($filename);
            return [$cnp, 'filename', $name];
        }

        return [null, null, null];
    }

    /**
     * Try to extract a human name from Hipocrate filename convention:
     *   Buletin_Analize_<CNP>_LastName_FirstName.pdf
     *
     * Returns "LastName FirstName" or null.
     */
    private function extractNameFromFilename(string $filename): ?string
    {
        $base = pathinfo($filename, PATHINFO_FILENAME);

        // Remove the 13-digit CNP and everything before it (prefix + CNP)
        // Pattern: anything_CNP13digits_Rest
        if (preg_match('/\d{13}_(.+)$/', $base, $m)) {
            $rest = $m[1];
            // Replace underscores with spaces and title-case
            $name = ucwords(strtolower(str_replace('_', ' ', $rest)));
            return $name ?: null;
        }

        return null;
    }

    /**
     * Find existing patient by CNP or create a new one.
     * If a name was extracted from the filename, use it for newly created patients.
     */
    private function findOrCreatePatient(string $cnp, ?int $hospitalId, ?string $extractedName): User
    {
        $patient = User::where('cnp_pacient', $cnp)
            ->where('role', 'patient')
            ->first();

        if ($patient) {
            if ($hospitalId && ! $patient->hospital_id) {
                $patient->update(['hospital_id' => $hospitalId]);
            }
            return $patient;
        }

        // Use extracted name if available, otherwise placeholder
        $name = $extractedName
            ?? ('Pacient ' . substr($cnp, 0, 4) . '****' . substr($cnp, -3));

        return User::create([
            'name'        => $name,
            'email'       => 'pacient.' . $cnp . '@hipocrate.internal',
            'password'    => bcrypt(Str::random(32)),
            'role'        => 'patient',
            'cnp_pacient' => $cnp,
            'hospital_id' => $hospitalId,
            'is_active'   => true,
        ]);
    }

    /**
     * Build a human-readable document name from the raw filename.
     * "Buletin_Analize_1234567890123_Popescu_Ion.pdf" → "Buletin analize - Popescu Ion"
     */
    private function buildDocumentName(string $filename): string
    {
        $base = pathinfo($filename, PATHINFO_FILENAME);

        // Extract name part after CNP if present
        $namePart = null;
        if (preg_match('/\d{13}_(.+)$/', $base, $m)) {
            $namePart = ucwords(strtolower(str_replace('_', ' ', $m[1])));
        }

        // Remove CNP from base
        $prefix = preg_replace('/\d{13}.*$/', '', $base);
        $prefix = trim(preg_replace('/[-_]+/', ' ', $prefix));
        $prefix = $prefix ? ucfirst(strtolower($prefix)) : 'Raport UPU';

        return $namePart ? "$prefix - $namePart" : $prefix . ' ' . now()->format('Y-m-d H:i');
    }

    private function inferHospitalId(Request $request): ?int
    {
        return $request->user()?->hospital_id;
    }

    private function authorised(Request $request): bool
    {
        if ($this->authorisedByApiKey($request)) {
            return true;
        }
        $user = $request->user();
        return $user && in_array($user->role, ['global_admin', 'hospital_admin', 'doctor']);
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

    private function resolveIngestedBy(Request $request): string
    {
        if ($this->authorisedByApiKey($request)) {
            return 'api_key';
        }
        return $request->user()?->email ?? 'unknown';
    }
}