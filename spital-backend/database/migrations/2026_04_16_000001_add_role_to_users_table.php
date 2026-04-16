<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('patient')->after('cnp_pacient');
            // 'global_admin' | 'hospital_admin' | 'doctor' | 'patient' | 'companion'
            $table->foreignId('hospital_id')->nullable()->constrained()->onDelete('set null')->after('role');
            $table->string('specialization')->nullable()->after('hospital_id'); // for doctors
            $table->string('license_number')->nullable()->after('specialization'); // for doctors
            $table->boolean('is_active')->default(true)->after('license_number');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['hospital_id']);
            $table->dropColumn(['role', 'hospital_id', 'specialization', 'license_number', 'is_active']);
        });
    }
};
