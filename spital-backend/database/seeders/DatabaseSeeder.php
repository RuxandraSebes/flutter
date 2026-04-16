<?php

namespace Database\Seeders;

use App\Models\Hospital;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ── 1. Global Admin ──────────────────────────────────────────────────
        User::firstOrCreate(
            ['email' => 'admin@spital.ro'],
            [
                'name'      => 'Administrator Global',
                'password'  => Hash::make('password'),
                'role'      => 'global_admin',
                'is_active' => true,
            ]
        );

        // ── 2. Hospital ───────────────────────────────────────────────────────
        $hospital = Hospital::firstOrCreate(
            ['name' => 'Spitalul Municipal Vișeu de Sus'],
            [
                'city'      => 'Vișeu de Sus',
                'address'   => 'Str. Principală nr. 1',
                'phone'     => '0262-352100',
                'email'     => 'contact@spital-viseu.ro',
                'is_active' => true,
            ]
        );

        // ── 3. Hospital Admin ─────────────────────────────────────────────────
        User::firstOrCreate(
            ['email' => 'admin.spital@spital.ro'],
            [
                'name'        => 'Admin Spital Vișeu',
                'password'    => Hash::make('password'),
                'role'        => 'hospital_admin',
                'hospital_id' => $hospital->id,
                'is_active'   => true,
            ]
        );

        // ── 4. Doctor ─────────────────────────────────────────────────────────
        User::firstOrCreate(
            ['email' => 'doctor@spital.ro'],
            [
                'name'           => 'Dr. Ioan Popescu',
                'password'       => Hash::make('password'),
                'role'           => 'doctor',
                'hospital_id'    => $hospital->id,
                'specialization' => 'Medicină de Urgență',
                'license_number' => 'RO-MED-001234',
                'is_active'      => true,
            ]
        );

        // ── 5. Patient ────────────────────────────────────────────────────────
        $patient = User::firstOrCreate(
            ['email' => 'pacient@spital.ro'],
            [
                'name'        => 'Maria Ionescu',
                'password'    => Hash::make('password'),
                'role'        => 'patient',
                'hospital_id' => $hospital->id,
                'cnp_pacient' => '2780412123456',
                'is_active'   => true,
            ]
        );

        // ── 6. Companion ──────────────────────────────────────────────────────
        $companion = User::firstOrCreate(
            ['email' => 'insotitor@spital.ro'],
            [
                'name'        => 'Ion Ionescu',
                'password'    => Hash::make('password'),
                'role'        => 'companion',
                'hospital_id' => $hospital->id,
                'is_active'   => true,
            ]
        );

        // Link companion → patient
        $patient->companions()->syncWithoutDetaching([
            $companion->id => [
                'relationship'       => 'soț',
                'can_view_documents' => true,
            ],
        ]);

        $this->command->info('✅  Seeded: admin, hospital, hospital_admin, doctor, patient, companion');
        $this->command->table(
            ['Role', 'Email', 'Password'],
            [
                ['global_admin',   'admin@spital.ro',         'password'],
                ['hospital_admin', 'admin.spital@spital.ro',  'password'],
                ['doctor',         'doctor@spital.ro',        'password'],
                ['patient',        'pacient@spital.ro',       'password'],
                ['companion',      'insotitor@spital.ro',     'password'],
            ]
        );
    }
}