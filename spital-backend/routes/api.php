<?php

use App\Http\Controllers\AccessCodeController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\PdfIngestionController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

// ── Public routes ─────────────────────────────────────────────────────────────
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login',    [AuthController::class, 'login']);

// Public hospital list — needed for the Register screen hospital picker
Route::get('/hospitals/public', function () {
    return response([
        'hospitals' => \App\Models\Hospital::where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'name', 'city'])
    ]);
});

// ── PDF Ingestion (API key OR authenticated doctor/admin) ─────────────────────
Route::post('/ingest/pdf',   [PdfIngestionController::class, 'ingest']);
Route::post('/ingest/poll',  [PdfIngestionController::class, 'pollFolder']);
Route::get('/ingest/status', [PdfIngestionController::class, 'status']);

// ── Protected routes ──────────────────────────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me',      [AuthController::class, 'me']);

    // Self-service profile update
    Route::put('/profile', [ProfileController::class, 'update']);

    // Documents — role filtering is inside the controller
    Route::get('/documents',         [DocumentController::class, 'index']);
    Route::post('/documents',        [DocumentController::class, 'store']);
    Route::delete('/documents/{id}', [DocumentController::class, 'destroy']);

    // ── Access codes (numeric, 5-minute TTL) ──────────────────────────────────
    Route::post('/access-codes/generate', [AccessCodeController::class, 'generate']);
    Route::post('/access-codes/redeem',   [AccessCodeController::class, 'redeem']);

    // ── Email invitations (24-hour TTL) ───────────────────────────────────────
    Route::post('/access-codes/invite',        [AccessCodeController::class, 'sendEmailInvite']);
    Route::post('/access-codes/invite/redeem', [AccessCodeController::class, 'redeemEmailInvite']);

    // ── REQ-5: Patient self-service — view & remove companions ────────────────
    Route::get('/my-companions',                  [AccessCodeController::class, 'myCompanions']);
    Route::delete('/my-companions/{companionId}', [AccessCodeController::class, 'unlinkMyCompanion']);

    // ── REQ-6: Companion self-service — view & remove linked patients ─────────
    Route::get('/my-patients',                [AccessCodeController::class, 'myPatients']);
    Route::delete('/my-patients/{patientId}', [AccessCodeController::class, 'unlinkMyPatient']);

    // ── Chat ──────────────────────────────────────────────────────────────────
    Route::get('/chat/conversations', [ChatController::class, 'conversations']);
    Route::get('/chat/messages',      [ChatController::class, 'messages']);
    Route::post('/chat/messages',     [ChatController::class, 'send']);

    // ── User listing — doctors + admins can READ the patient list ─────────────
    Route::middleware('role:global_admin,hospital_admin,doctor')->group(function () {
        Route::get('/users', [AdminController::class, 'listUsers']);
    });

    // ── Hospital management (global_admin only) ────────────────────────────────
    Route::middleware('role:global_admin')->group(function () {
        Route::get('/hospitals',         [AdminController::class, 'listHospitals']);
        Route::post('/hospitals',        [AdminController::class, 'createHospital']);
        Route::put('/hospitals/{id}',    [AdminController::class, 'updateHospital']);
        Route::delete('/hospitals/{id}', [AdminController::class, 'deleteHospital']);
    });

    // ── User management writes (global_admin + hospital_admin) ────────────────
    Route::middleware('role:global_admin,hospital_admin')->group(function () {
        Route::post('/users',          [AdminController::class, 'createUser']);
        Route::put('/users/{id}',      [AdminController::class, 'updateUser']);
        Route::delete('/users/{id}',   [AdminController::class, 'deleteUser']);

        // REQ-13: relationship field removed from link (handled in controller)
        Route::post('/companions/link',   [AdminController::class, 'linkCompanion']);
        Route::post('/companions/unlink', [AdminController::class, 'unlinkCompanion']);
    });
});