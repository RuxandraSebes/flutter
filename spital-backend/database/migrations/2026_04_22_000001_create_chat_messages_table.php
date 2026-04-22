<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chat_messages', function (Blueprint $table) {
            $table->id();

            // The patient this conversation belongs to
            $table->foreignId('patient_id')
                  ->constrained('users')
                  ->onDelete('cascade');

            // Who sent this message
            $table->foreignId('sender_id')
                  ->constrained('users')
                  ->onDelete('cascade');

            // Cached sender name (so messages survive user renames)
            $table->string('sender_name');

            // 'patient_side' = sent by patient or their companion
            // 'doctor_side'  = sent by doctor, hospital_admin, global_admin
            $table->string('sender_role'); // patient_side | doctor_side

            $table->text('message');

            // Null = unread by the other side
            $table->timestamp('read_at')->nullable();

            $table->timestamps();

            $table->index(['patient_id', 'created_at']);
            $table->index(['patient_id', 'sender_role', 'read_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chat_messages');
    }
};
