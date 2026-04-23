<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * Register — patients and companions can self-register.
     * REQ-17: CNP is now mandatory for both patient and companion roles.
     * REQ-18: is_active removed from create — auto-set to true.
     */
    public function register(Request $request)
    {
        // REQ-17: cnp_pacient is required for patient and companion
        $roleInput = $request->input('role', 'patient');

        $rules = [
            'name'        => 'required|string|max:255',
            'email'       => 'required|string|email|unique:users,email',
            'password'    => 'required|string|min:6|confirmed',
            'role'        => 'sometimes|in:patient,companion',
            'hospital_id' => 'nullable|exists:hospitals,id',
        ];

        if (in_array($roleInput, ['patient', 'companion'])) {
            $rules['cnp_pacient'] = 'required|string|size:13';
        } else {
            $rules['cnp_pacient'] = 'nullable|string|size:13';
        }

        $fields = $request->validate($rules);

        $user = User::create([
            'name'        => $fields['name'],
            'email'       => $fields['email'],
            'password'    => bcrypt($fields['password']),
            'cnp_pacient' => $fields['cnp_pacient'] ?? null,
            'role'        => $fields['role'] ?? 'patient',
            'hospital_id' => $fields['hospital_id'] ?? null,
            'is_active'   => true, // REQ-18: always active on creation
        ]);

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $this->formatUser($user->load('hospital')),
            'token' => $token,
        ], 201);
    }

    public function login(Request $request)
    {
        $fields = $request->validate([
            'email'    => 'required|string|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $fields['email'])->first();

        if (! $user || ! Hash::check($fields['password'], $user->password)) {
            return response(['message' => 'Date incorecte'], 401);
        }

        if (! $user->is_active) {
            return response(['message' => 'Contul este dezactivat. Contactati administratorul.'], 403);
        }

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $this->formatUser($user->load('hospital')),
            'token' => $token,
        ], 200);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response(['message' => 'Delogat cu succes'], 200);
    }

    public function me(Request $request)
    {
        return response($this->formatUser($request->user()->load('hospital')), 200);
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
                'city' => $user->hospital->city,
            ] : null,
            'specialization' => $user->specialization,
            'license_number' => $user->license_number,
            'is_active'      => $user->is_active,
        ];
    }
}