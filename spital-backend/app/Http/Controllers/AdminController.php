<?php

namespace App\Http\Controllers;

use App\Models\Hospital;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    // ══════════════════════════════════════════════════════════════════════════
    //  HOSPITAL MANAGEMENT  (global_admin only)
    // ══════════════════════════════════════════════════════════════════════════

    public function listHospitals()
    {
        return response(['hospitals' => Hospital::withCount('users')->get()], 200);
    }

    public function createHospital(Request $request)
    {
        $fields = $request->validate([
            'name'    => 'required|string|max:255',
            'city'    => 'required|string|max:255',
            'address' => 'nullable|string',
            'phone'   => 'nullable|string|max:20',
            'email'   => 'nullable|email|max:255',
            // REQ-18: is_active removed from create — defaults to true automatically
        ]);

        $hospital = Hospital::create($fields);

        return response(['hospital' => $hospital], 201);
    }

    public function updateHospital(Request $request, int $id)
    {
        $hospital = Hospital::findOrFail($id);

        $fields = $request->validate([
            'name'      => 'sometimes|string|max:255',
            'city'      => 'sometimes|string|max:255',
            'address'   => 'nullable|string',
            'phone'     => 'nullable|string|max:20',
            'email'     => 'nullable|email|max:255',
            'is_active' => 'sometimes|boolean', // allowed on UPDATE only
        ]);

        $hospital->update($fields);

        return response(['hospital' => $hospital], 200);
    }

    public function deleteHospital(int $id)
    {
        $hospital = Hospital::findOrFail($id);
        $hospital->delete();

        return response(['message' => 'Spitalul a fost sters'], 200);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  USER MANAGEMENT
    // ══════════════════════════════════════════════════════════════════════════

    public function listUsers(Request $request)
    {
        $actor = $request->user();
        $query = User::with('hospital');

        if ($actor->isGlobalAdmin()) {
            // no filter — sees everyone
        } elseif ($actor->isHospitalAdmin()) {
            $query->where('hospital_id', $actor->hospital_id);
        } elseif ($actor->isDoctor()) {
            $query->whereIn('role', ['patient', 'companion']);
        } else {
            return response(['users' => []], 200);
        }

        $role = $request->query('role');
        if ($role) {
            $query->where('role', $role);
        }

        return response(['users' => $query->get()->map(fn($u) => $this->formatUser($u))], 200);
    }

    public function createUser(Request $request)
    {
        $actor        = $request->user();
        $allowedRoles = $this->allowedRolesToCreate($actor);

        // REQ-17: CNP mandatory for patient and companion
        // REQ-16: For doctors, keep only specialization + make CNP optional (doctors use license_number)
        // REQ-18: is_active removed from create forms (auto-set to true)
        // REQ-19: global_admin has no hospital_id field (not tied to a hospital)
        $rules = [
            'name'           => 'required|string|max:255',
            'email'          => 'required|email|unique:users,email',
            'password'       => 'required|string|min:6',
            'role'           => ['required', Rule::in($allowedRoles)],
            'cnp_pacient'    => 'nullable|string|size:13',
            'specialization' => 'nullable|string|max:255',
            // REQ-16: license_number removed for doctors (kept for DB compatibility but not required)
        ];

        // REQ-19: global_admin should not have hospital_id
        if (! $actor->isGlobalAdmin()) {
            $rules['hospital_id'] = 'nullable|exists:hospitals,id';
        }

        // REQ-17: CNP is mandatory for patients and companions
        $roleInput = $request->input('role');
        if (in_array($roleInput, ['patient', 'companion'])) {
            $rules['cnp_pacient'] = 'required|string|size:13';
        }

        $fields = $request->validate($rules);

        // REQ-18: always start as active
        $fields['is_active'] = true;

        if ($actor->isHospitalAdmin()) {
            $fields['hospital_id'] = $actor->hospital_id;
        }

        // REQ-19: global_admin is not assigned to any hospital
        if ($actor->isGlobalAdmin() && ($fields['role'] ?? '') === 'global_admin') {
            unset($fields['hospital_id']);
        }

        $user = User::create([
            ...$fields,
            'password' => bcrypt($fields['password']),
        ]);

        return response(['user' => $this->formatUser($user)], 201);
    }

    public function updateUser(Request $request, int $id)
    {
        $actor = $request->user();
        $user  = User::findOrFail($id);

        if ($actor->isHospitalAdmin() && $user->hospital_id !== $actor->hospital_id) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $allowedRoles = $this->allowedRolesToCreate($actor);

        $rules = [
            'name'           => 'sometimes|string|max:255',
            'email'          => ['sometimes', 'email', Rule::unique('users')->ignore($user->id)],
            'role'           => ['sometimes', Rule::in($allowedRoles)],
            'specialization' => 'nullable|string|max:255',
            'license_number' => 'nullable|string|max:100',
            'is_active'      => 'sometimes|boolean', // allowed on update
            'cnp_pacient'    => 'nullable|string|size:13',
        ];

        // REQ-19: global_admin cannot have hospital_id
        if (! $actor->isGlobalAdmin()) {
            $rules['hospital_id'] = 'nullable|exists:hospitals,id';
        }

        $fields = $request->validate($rules);

        if ($actor->isHospitalAdmin()) {
            unset($fields['hospital_id']);
        }

        $user->update($fields);

        return response(['user' => $this->formatUser($user->fresh())], 200);
    }

    public function deleteUser(Request $request, int $id)
    {
        $actor = $request->user();
        $user  = User::findOrFail($id);

        if ($actor->isHospitalAdmin() && $user->hospital_id !== $actor->hospital_id) {
            return response(['message' => 'Acces interzis'], 403);
        }

        if ($actor->id === $user->id) {
            return response(['message' => 'Nu poti sterge propriul cont din aceasta interfata'], 422);
        }

        $user->delete();

        return response(['message' => 'Utilizatorul a fost sters'], 200);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  COMPANION LINKING
    //  REQ-13: Remove "relationship" field from link
    // ══════════════════════════════════════════════════════════════════════════

    public function linkCompanion(Request $request)
    {
        // REQ-13: relationship field removed
        $fields = $request->validate([
            'patient_id'         => 'required|exists:users,id',
            'companion_id'       => 'required|exists:users,id',
            'can_view_documents' => 'boolean',
        ]);

        $patient   = User::findOrFail($fields['patient_id']);
        $companion = User::findOrFail($fields['companion_id']);

        if (! $patient->isPatient()) {
            return response(['message' => 'Utilizatorul selectat nu este pacient'], 422);
        }
        if (! $companion->isCompanion()) {
            return response(['message' => 'Utilizatorul selectat nu este insotitor'], 422);
        }

        $patient->companions()->syncWithoutDetaching([
            $fields['companion_id'] => [
                'relationship'       => null, // REQ-13: always null, field removed from UI
                'can_view_documents' => $fields['can_view_documents'] ?? true,
            ],
        ]);

        return response(['message' => 'Insotitor legat cu succes'], 200);
    }

    public function unlinkCompanion(Request $request)
    {
        $fields = $request->validate([
            'patient_id'   => 'required|exists:users,id',
            'companion_id' => 'required|exists:users,id',
        ]);

        $patient = User::findOrFail($fields['patient_id']);
        $patient->companions()->detach($fields['companion_id']);

        return response(['message' => 'Insotitor dezlegat'], 200);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Private helpers
    // ══════════════════════════════════════════════════════════════════════════

    private function allowedRolesToCreate(User $actor): array
    {
        if ($actor->isGlobalAdmin()) {
            return User::ROLES;
        }
        if ($actor->isHospitalAdmin()) {
            return [User::ROLE_DOCTOR, User::ROLE_PATIENT, User::ROLE_COMPANION];
        }
        return [];
    }

    private function formatUser(User $user): array
    {
        return [
            'id'             => $user->id,
            'name'           => $user->name,
            'email'          => $user->email,
            'role'           => $user->role,
            'cnp_pacient'    => $user->cnp_pacient,
            'hospital_id'    => $user->hospital_id,
            'hospital'       => $user->hospital ? [
                'id'   => $user->hospital->id,
                'name' => $user->hospital->name,
            ] : null,
            'specialization' => $user->specialization,
            'license_number' => $user->license_number,
            'is_active'      => $user->is_active,
            'created_at'     => $user->created_at?->toDateTimeString(),
        ];
    }
}