<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    const ROLE_GLOBAL_ADMIN   = 'global_admin';
    const ROLE_HOSPITAL_ADMIN = 'hospital_admin';
    const ROLE_DOCTOR         = 'doctor';
    const ROLE_PATIENT        = 'patient';
    const ROLE_COMPANION      = 'companion';

    const ROLES = [
        self::ROLE_GLOBAL_ADMIN,
        self::ROLE_HOSPITAL_ADMIN,
        self::ROLE_DOCTOR,
        self::ROLE_PATIENT,
        self::ROLE_COMPANION,
    ];

    protected $fillable = [
        'name',
        'email',
        'password',
        'cnp_pacient',
        'role',
        'hospital_id',
        'specialization',
        'license_number',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password'          => 'hashed',
        'is_active'         => 'boolean',
    ];

    // ── Role helpers ─────────────────────────────────────────────────────────

    public function isGlobalAdmin(): bool
    {
        return $this->role === self::ROLE_GLOBAL_ADMIN;
    }

    public function isHospitalAdmin(): bool
    {
        return $this->role === self::ROLE_HOSPITAL_ADMIN;
    }

    public function isDoctor(): bool
    {
        return $this->role === self::ROLE_DOCTOR;
    }

    public function isPatient(): bool
    {
        return $this->role === self::ROLE_PATIENT;
    }

    public function isCompanion(): bool
    {
        return $this->role === self::ROLE_COMPANION;
    }

    public function hasRole(string $role): bool
    {
        return $this->role === $role;
    }

    public function canManageHospital(int $hospitalId): bool
    {
        if ($this->isGlobalAdmin()) {
            return true;
        }
        return $this->isHospitalAdmin() && $this->hospital_id === $hospitalId;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function hospital()
    {
        return $this->belongsTo(Hospital::class);
    }

    public function documents()
    {
        return $this->hasMany(Document::class);
    }

    /**
     * Companions linked to this patient.
     */
    public function companions()
    {
        return $this->belongsToMany(
            User::class,
            'patient_companions',
            'patient_id',
            'companion_id'
        )->withPivot('relationship', 'can_view_documents')->withTimestamps();
    }

    /**
     * Patients this companion is linked to.
     */
    public function patients()
    {
        return $this->belongsToMany(
            User::class,
            'patient_companions',
            'companion_id',
            'patient_id'
        )->withPivot('relationship', 'can_view_documents')->withTimestamps();
    }
}