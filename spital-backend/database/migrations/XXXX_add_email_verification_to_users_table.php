<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('email_verification_token', 6)->nullable()->after('email');
            $table->timestamp('email_verification_token_expires_at')->nullable()->after('email_verification_token');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'email_verification_token',
                'email_verification_token_expires_at',
                'email_verified_at',
            ]);
        });
    }
};