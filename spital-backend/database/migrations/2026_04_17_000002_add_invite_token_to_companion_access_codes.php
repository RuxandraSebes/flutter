<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companion_access_codes', function (Blueprint $table) {
            // Token for email-based invites (null = numeric code type)
            $table->string('invite_token', 64)->nullable()->unique()->after('code');
            // The email the invite was sent to
            $table->string('companion_email')->nullable()->after('invite_token');

            // Index for fast token lookups
            $table->index('invite_token');
        });
    }

    public function down(): void
    {
        Schema::table('companion_access_codes', function (Blueprint $table) {
            $table->dropIndex(['invite_token']);
            $table->dropColumn(['invite_token', 'companion_email']);
        });
    }
};
