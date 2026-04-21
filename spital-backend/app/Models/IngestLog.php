<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class IngestLog extends Model
{
    protected $fillable = [
        'filename',
        'cnp_extracted',
        'cnp_source',
        'patient_id',
        'patient_created',
        'document_id',
        'status',
        'error_message',
        'ingested_by',
    ];

    protected $casts = [
        'patient_created' => 'boolean',
    ];

    public function patient()
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function document()
    {
        return $this->belongsTo(Document::class, 'document_id');
    }
}