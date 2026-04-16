<?php

namespace App\Http\Controllers;

use App\Models\Document;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class DocumentController extends Controller
{
    /**
     * List documents — respects role:
     *   - patient/companion: own or linked patient docs
     *   - doctor/hospital_admin: docs of patients in same hospital
     *   - global_admin: all docs
     */
    public function index(Request $request)
    {
        $user  = $request->user();
        $query = Document::with('user');

        switch ($user->role) {
            case 'global_admin':
                // no filter
                break;

            case 'hospital_admin':
            case 'doctor':
                // docs belonging to patients in the same hospital
                $query->whereHas('user', function ($q) use ($user) {
                    $q->where('hospital_id', $user->hospital_id)
                      ->where('role', 'patient');
                });
                break;

            case 'companion':
                // own docs + docs of linked patients (where can_view_documents = true)
                $patientIds = $user->patients()
                    ->wherePivot('can_view_documents', true)
                    ->pluck('users.id');

                $query->where(function ($q) use ($user, $patientIds) {
                    $q->where('user_id', $user->id)
                      ->orWhereIn('user_id', $patientIds);
                });
                break;

            case 'patient':
            default:
                $query->where('user_id', $user->id);
                break;
        }

        // Optional filter by patient id (for doctor/admin)
        if ($request->has('patient_id') && in_array($user->role, ['doctor', 'hospital_admin', 'global_admin'])) {
            $query->where('user_id', $request->query('patient_id'));
        }

        $documents = $query->orderBy('created_at', 'desc')
            ->get()
            ->map(fn($doc) => $this->formatDoc($doc));

        return response(['documents' => $documents], 200);
    }

    /**
     * Upload a PDF document.
     * Doctors / admins can upload on behalf of a patient by passing patient_id.
     */
    public function store(Request $request)
    {
        $request->validate([
            'file'       => 'required|file|mimes:pdf|max:20480',
            'name'       => 'nullable|string|max:255',
            'patient_id' => 'nullable|exists:users,id',
        ]);

        $user = $request->user();

        // Determine the owner of the document
        $ownerId = $user->id;

        if ($request->filled('patient_id')) {
            if (! in_array($user->role, ['doctor', 'hospital_admin', 'global_admin'])) {
                return response(['message' => 'Acces interzis'], 403);
            }
            $patient = User::findOrFail($request->input('patient_id'));
            if (! $patient->isPatient()) {
                return response(['message' => 'ID-ul specificat nu aparține unui pacient'], 422);
            }
            $ownerId = $patient->id;
        }

        $file = $request->file('file');
        $name = $request->input('name') ?? $file->getClientOriginalName();
        $path = $file->store('documents/' . $ownerId, 'public');

        $document = Document::create([
            'user_id' => $ownerId,
            'name'    => $name,
            'path'    => $path,
        ]);

        return response(['document' => $this->formatDoc($document)], 201);
    }

    /**
     * Delete a document.
     */
    public function destroy(Request $request, int $id)
    {
        $user     = $request->user();
        $document = Document::findOrFail($id);

        $canDelete = match ($user->role) {
            'global_admin'   => true,
            'hospital_admin' => $document->user->hospital_id === $user->hospital_id,
            'doctor'         => $document->user->hospital_id === $user->hospital_id,
            default          => $document->user_id === $user->id,
        };

        if (! $canDelete) {
            return response(['message' => 'Acces interzis'], 403);
        }

        Storage::disk('public')->delete($document->path);
        $document->delete();

        return response(['message' => 'Document șters'], 200);
    }

    // ── Private helper ────────────────────────────────────────────────────────

    private function formatDoc(Document $doc): array
    {
        return [
            'id'         => $doc->id,
            'name'       => $doc->name,
            'url'        => url('storage/' . $doc->path),
            'created_at' => $doc->created_at->toDateTimeString(),
            'owner'      => $doc->user ? [
                'id'   => $doc->user->id,
                'name' => $doc->user->name,
                'role' => $doc->user->role,
            ] : null,
        ];
    }
}