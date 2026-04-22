<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ChatMessage extends Model
{
    protected $fillable = [
        'patient_id',
        'sender_id',
        'sender_name',
        'sender_role',
        'message',
        'read_at',
    ];

    protected $casts = [
        'read_at' => 'datetime',
    ];

    public function patient()
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function isFromDoctor(): bool
    {
        return $this->sender_role === 'doctor_side';
    }

    public function isFromPatient(): bool
    {
        return $this->sender_role === 'patient_side';
    }
}