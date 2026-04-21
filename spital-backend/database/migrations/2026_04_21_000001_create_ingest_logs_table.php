<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Track every PDF ingestion attempt for audit and debugging.
     */
    public function up(): void
    {
        Schema::create('ingest_logs', function (Blueprint $table) {
            $table->id();
            $table->string('filename');
            $table->string('cnp_extracted', 13)->nullable();
            $table->string('cnp_source')->nullable(); // 'explicit' | 'filename' | 'pdf_text'
            $table->foreignId('patient_id')->nullable()->constrained('users')->onDelete('set null');
            $table->boolean('patient_created')->default(false);
            $table->foreignId('document_id')->nullable()->constrained('documents')->onDelete('set null');
            $table->string('status')->default('success'); // 'success' | 'failed' | 'no_cnp'
            $table->text('error_message')->nullable();
            $table->string('ingested_by')->nullable(); // 'api_key' | user email
            $table->timestamps();

            $table->index(['cnp_extracted', 'status']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ingest_logs');
    }
};
