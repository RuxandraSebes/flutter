<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CompanionAccessCode extends Model
{
    protected $fillable = [
        'patient_id',
        'code',
        'invite_token',
        'companion_email',
        'expires_at',
        'used',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'used'       => 'boolean',
    ];

    public function patient()
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function isValid(): bool
    {
        return ! $this->used && $this->expires_at->isFuture();
    }

    public function isEmailType(): bool
    {
        return ! is_null($this->invite_token);
    }
}