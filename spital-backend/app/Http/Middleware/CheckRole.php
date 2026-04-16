<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRole
{
    /**
     * Handle an incoming request.
     *
     * Usage in routes:  ->middleware('role:global_admin,hospital_admin')
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json(['message' => 'Neautentificat'], 401);
        }

        if (! $user->is_active) {
            return response()->json(['message' => 'Contul este dezactivat'], 403);
        }

        if (empty($roles) || in_array($user->role, $roles)) {
            return $next($request);
        }

        return response()->json([
            'message' => 'Acces interzis. Rol insuficient.',
            'required_roles' => $roles,
            'your_role' => $user->role,
        ], 403);
    }
}