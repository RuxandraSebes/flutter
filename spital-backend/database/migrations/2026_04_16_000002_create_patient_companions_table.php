<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('patient_companions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('patient_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('companion_id')->constrained('users')->onDelete('cascade');
            $table->string('relationship')->nullable(); // e.g. "parent", "spouse"
            $table->boolean('can_view_documents')->default(true);
            $table->timestamps();

            $table->unique(['patient_id', 'companion_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('patient_companions');
    }
};
