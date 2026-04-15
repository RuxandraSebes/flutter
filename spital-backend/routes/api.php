<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\DocumentController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login',    [AuthController::class, 'login']);

// Protected routes (require Sanctum token)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me',      [AuthController::class, 'me']);

    // Documents
    Route::get('/documents',          [DocumentController::class, 'index']);
    Route::post('/documents',         [DocumentController::class, 'store']);
    Route::delete('/documents/{id}',  [DocumentController::class, 'destroy']);
});