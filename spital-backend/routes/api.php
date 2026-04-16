<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\DocumentController;
use Illuminate\Support\Facades\Route;

// ── Public routes ─────────────────────────────────────────────────────────────
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login',    [AuthController::class, 'login']);

// ── Protected routes ──────────────────────────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me',      [AuthController::class, 'me']);

    // Documents — all authenticated users, role filtering is inside the controller
    Route::get('/documents',          [DocumentController::class, 'index']);
    Route::post('/documents',         [DocumentController::class, 'store']);
    Route::delete('/documents/{id}',  [DocumentController::class, 'destroy']);

    // ── Hospital management (global_admin only) ────────────────────────────────
    Route::middleware('role:global_admin')->group(function () {
        Route::get('/hospitals',          [AdminController::class, 'listHospitals']);
        Route::post('/hospitals',         [AdminController::class, 'createHospital']);
        Route::put('/hospitals/{id}',     [AdminController::class, 'updateHospital']);
        Route::delete('/hospitals/{id}',  [AdminController::class, 'deleteHospital']);
    });

    // ── User management (global_admin + hospital_admin) ────────────────────────
    Route::middleware('role:global_admin,hospital_admin')->group(function () {
        Route::get('/users',           [AdminController::class, 'listUsers']);
        Route::post('/users',          [AdminController::class, 'createUser']);
        Route::put('/users/{id}',      [AdminController::class, 'updateUser']);
        Route::delete('/users/{id}',   [AdminController::class, 'deleteUser']);

        // Companion linking
        Route::post('/companions/link',    [AdminController::class, 'linkCompanion']);
        Route::post('/companions/unlink',  [AdminController::class, 'unlinkCompanion']);
    });
});