<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $fields = $request->validate([
            'name'         => 'required|string|max:255',
            'email'        => 'required|string|email|unique:users,email',
            'password'     => 'required|string|min:6|confirmed',
            'cnp_pacient'  => 'nullable|string|size:13',
        ]);

        $user = User::create([
            'name'        => $fields['name'],
            'email'       => $fields['email'],
            'password'    => bcrypt($fields['password']),
            'cnp_pacient' => $fields['cnp_pacient'] ?? null,
        ]);

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $user,
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

        if (!$user || !Hash::check($fields['password'], $user->password)) {
            return response(['message' => 'Date incorecte'], 401);
        }

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $user,
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
        return response($request->user(), 200);
    }
}