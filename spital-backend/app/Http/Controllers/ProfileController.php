<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ProfileController extends Controller
{
    /**
     * GET /api/me  (already exists on AuthController, but duplicated here
     * for clarity — the route still points to AuthController::me)
     *
     * PUT /api/profile
     * Allows any authenticated user to update their own name and email.
     * Patients auto-created by Hipocrate ingestion use this to "claim"
     * their account (replace placeholder name + @hipocrate.internal email).
     */
    public function update(Request $request)
    {
        $user = $request->user();

        $fields = $request->validate([
            'name'     => 'sometimes|string|max:255',
            'email'    => [
                'sometimes',
                'email',
                'max:255',
                Rule::unique('users')->ignore($user->id),
            ],
            'password' => 'sometimes|string|min:6|confirmed',
        ]);

        if (isset($fields['password'])) {
            $fields['password'] = bcrypt($fields['password']);
        }

        $user->update($fields);

        return response([
            'user' => [
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
            ],
        ], 200);
    }
}