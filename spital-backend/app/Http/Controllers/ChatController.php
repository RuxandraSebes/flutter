<?php
// REQ-11: Added total_count (total messages per conversation) to conversations endpoint

namespace App\Http\Controllers;

use App\Models\ChatMessage;
use App\Models\User;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    /**
     * List conversations.
     * REQ-11: each conversation now includes total_count (total messages in thread).
     */
    public function conversations(Request $request)
    {
        $user = $request->user();

        if ($user->isDoctor() || $user->isHospitalAdmin() || $user->isGlobalAdmin()) {
            $patientIds = ChatMessage::select('patient_id')
                ->distinct()
                ->pluck('patient_id');

            $patients = User::whereIn('id', $patientIds)
                ->with('hospital')
                ->get()
                ->map(function ($patient) use ($user) {
                    $lastMsg = ChatMessage::where('patient_id', $patient->id)
                        ->orderBy('created_at', 'desc')
                        ->first();

                    $unread = ChatMessage::where('patient_id', $patient->id)
                        ->where('sender_role', 'patient_side')
                        ->whereNull('read_at')
                        ->count();

                    // REQ-11: total message count for this conversation
                    $total = ChatMessage::where('patient_id', $patient->id)->count();

                    return [
                        'patient_id'   => $patient->id,
                        'patient_name' => $patient->name,
                        'last_message' => $lastMsg ? $lastMsg->message : null,
                        'last_time'    => $lastMsg ? $lastMsg->created_at->toIso8601String() : null,
                        'unread_count' => $unread,
                        'total_count'  => $total, // REQ-11
                    ];
                });

            return response(['conversations' => $patients], 200);
        }

        if ($user->isPatient()) {
            $lastMsg = ChatMessage::where('patient_id', $user->id)
                ->orderBy('created_at', 'desc')
                ->first();

            $unread = ChatMessage::where('patient_id', $user->id)
                ->where('sender_role', 'doctor_side')
                ->whereNull('read_at')
                ->count();

            // REQ-11: total count
            $total = ChatMessage::where('patient_id', $user->id)->count();

            return response([
                'conversations' => [[
                    'patient_id'   => $user->id,
                    'patient_name' => $user->name,
                    'last_message' => $lastMsg?->message,
                    'last_time'    => $lastMsg?->created_at->toIso8601String(),
                    'unread_count' => $unread,
                    'total_count'  => $total, // REQ-11
                ]],
            ], 200);
        }

        if ($user->isCompanion()) {
            $patientIds = $user->patients()
                ->wherePivot('can_view_documents', true)
                ->pluck('users.id');

            $conversations = [];
            foreach ($patientIds as $patientId) {
                $patient = User::find($patientId);
                if (! $patient) continue;

                $lastMsg = ChatMessage::where('patient_id', $patientId)
                    ->orderBy('created_at', 'desc')
                    ->first();

                $unread = ChatMessage::where('patient_id', $patientId)
                    ->where('sender_role', 'doctor_side')
                    ->whereNull('read_at')
                    ->count();

                // REQ-11: total count
                $total = ChatMessage::where('patient_id', $patientId)->count();

                $conversations[] = [
                    'patient_id'   => $patientId,
                    'patient_name' => $patient->name,
                    'last_message' => $lastMsg?->message,
                    'last_time'    => $lastMsg?->created_at->toIso8601String(),
                    'unread_count' => $unread,
                    'total_count'  => $total, // REQ-11
                ];
            }

            return response(['conversations' => $conversations], 200);
        }

        return response(['conversations' => []], 200);
    }

    /**
     * Get messages for a conversation.
     */
    public function messages(Request $request)
    {
        $request->validate([
            'patient_id' => 'required|exists:users,id',
        ]);

        $user      = $request->user();
        $patientId = (int) $request->query('patient_id');

        if (! $this->canAccessConversation($user, $patientId)) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $messages = ChatMessage::where('patient_id', $patientId)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(fn($m) => $this->formatMessage($m));

        if ($user->isPatient() || $user->isCompanion()) {
            ChatMessage::where('patient_id', $patientId)
                ->where('sender_role', 'doctor_side')
                ->whereNull('read_at')
                ->update(['read_at' => now()]);
        }

        if ($user->isDoctor() || $user->isHospitalAdmin() || $user->isGlobalAdmin()) {
            ChatMessage::where('patient_id', $patientId)
                ->where('sender_role', 'patient_side')
                ->whereNull('read_at')
                ->update(['read_at' => now()]);
        }

        return response(['messages' => $messages], 200);
    }

    /**
     * Send a message.
     */
    public function send(Request $request)
    {
        $request->validate([
            'patient_id' => 'required|exists:users,id',
            'message'    => 'required|string|max:2000',
        ]);

        $user      = $request->user();
        $patientId = (int) $request->input('patient_id');

        if (! $this->canAccessConversation($user, $patientId)) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $patient = User::findOrFail($patientId);
        if (! $patient->isPatient()) {
            return response(['message' => 'patient_id nu apartine unui pacient'], 422);
        }

        $senderRole = ($user->isPatient() || $user->isCompanion())
            ? 'patient_side'
            : 'doctor_side';

        $msg = ChatMessage::create([
            'patient_id'  => $patientId,
            'sender_id'   => $user->id,
            'sender_name' => $user->name,
            'sender_role' => $senderRole,
            'message'     => $request->input('message'),
        ]);

        return response(['message' => $this->formatMessage($msg)], 201);
    }

    private function canAccessConversation(User $user, int $patientId): bool
    {
        if ($user->isGlobalAdmin() || $user->isHospitalAdmin() || $user->isDoctor()) {
            return true;
        }
        if ($user->isPatient()) {
            return $user->id === $patientId;
        }
        if ($user->isCompanion()) {
            return $user->patients()
                ->wherePivot('can_view_documents', true)
                ->where('users.id', $patientId)
                ->exists();
        }
        return false;
    }

    private function formatMessage(ChatMessage $m): array
    {
        return [
            'id'          => $m->id,
            'patient_id'  => $m->patient_id,
            'sender_id'   => $m->sender_id,
            'sender_name' => $m->sender_name,
            'sender_role' => $m->sender_role,
            'message'     => $m->message,
            'read_at'     => $m->read_at?->toIso8601String(),
            'created_at'  => $m->created_at->toIso8601String(),
        ];
    }
}