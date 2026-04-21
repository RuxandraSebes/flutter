<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Auto-poll the ingest watch folder every minute
// To run manually: php artisan ingest:poll
Schedule::command('ingest:poll')->everyMinute()->withoutOverlapping();