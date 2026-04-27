<?php
namespace App\Http\Controllers;

use App\Models\ChatMessage;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ChatController extends Controller
{
    // ─── Helpers ────────────────────────────────────────────────────────────

    private function getLastSeen(int $userId, int $patientId): ?\Carbon\Carbon
    {
        $row = DB::table('conversation_last_seen')
            ->where('user_id', $userId)
            ->where('patient_id', $patientId)
            ->value('last_seen_at');

        return $row ? \Carbon\Carbon::parse($row) : null;
    }

    /**
     * Bulk-fetch last_seen_at for multiple patient IDs at once.
     * Returns an array keyed by patient_id → Carbon|null.
     */
    private function getLastSeenBulk(int $userId, array $patientIds): array
    {
        $rows = DB::table('conversation_last_seen')
            ->where('user_id', $userId)
            ->whereIn('patient_id', $patientIds)
            ->pluck('last_seen_at', 'patient_id');

        $result = [];
        foreach ($patientIds as $pid) {
            $raw = $rows[$pid] ?? null;
            $result[$pid] = $raw ? \Carbon\Carbon::parse($raw) : null;
        }
        return $result;
    }

    /**
     * Counts ALL messages after last_seen_at, regardless of sender.
     * If last_seen_at is NULL (never opened) → all messages are unread.
     * If last_seen_at is provided but there are NO messages yet → returns 0.
     */
    private function unreadCount(int $userId, int $patientId): int
    {
        $lastSeen = $this->getLastSeen($userId, $patientId);
        return $this->unreadCountFromTimestamp($patientId, $lastSeen);
    }

    private function unreadCountFromTimestamp(int $patientId, ?\Carbon\Carbon $lastSeen): int
    {
        // KEY FIX: if never opened, only count messages that actually EXIST.
        // Do NOT return "all messages" blindly — return the real count.
        $query = ChatMessage::where('patient_id', $patientId);

        if ($lastSeen) {
            $query->where('created_at', '>', $lastSeen);
        }
        // null lastSeen → counts everything (correct: never seen this conversation)

        return $query->count();
    }

    private function markSeen(int $userId, int $patientId): void
    {
        DB::table('conversation_last_seen')->updateOrInsert(
            // match condition
            [
                'user_id'    => $userId,
                'patient_id' => $patientId,
            ],
            // value to write — +1 second so the current batch of messages
            // falls safely behind the cursor and won't re-appear as unread
            [
                'last_seen_at' => now()->addSecond(),
            ]
        );
    }

    // ─── Conversations ───────────────────────────────────────────────────────

    public function conversations(Request $request)
    {
        $user = $request->user();

        if ($user->isDoctor() || $user->isHospitalAdmin() || $user->isGlobalAdmin()) {
            $patientIds = ChatMessage::select('patient_id')
                ->distinct()
                ->pluck('patient_id')
                ->toArray();

            // Single query for all last_seen timestamps — no N+1
            $lastSeenMap = $this->getLastSeenBulk($user->id, $patientIds);

            // Single query for all unread counts grouped by patient
            $unreadMap = ChatMessage::whereIn('patient_id', $patientIds)
                ->selectRaw('patient_id, COUNT(*) as cnt, MAX(created_at) as latest')
                ->groupBy('patient_id')
                ->get()
                ->keyBy('patient_id');

            $conversations = User::whereIn('id', $patientIds)
                ->with('hospital')
                ->get()
                ->map(function ($patient) use ($user, $lastSeenMap, $unreadMap) {
                    $lastMsg = ChatMessage::where('patient_id', $patient->id)
                        ->orderBy('created_at', 'desc')
                        ->first();

                    $total      = $unreadMap[$patient->id]->cnt ?? 0;
                    $lastSeen   = $lastSeenMap[$patient->id] ?? null;

                    // For a doctor who has NEVER opened a conversation,
                    // unread = 0 (not "every message ever"). They didn't miss
                    // anything — the conversation existed before their account.
                    // Only count as unread messages sent AFTER they first logged in,
                    // approximated as: if never seen → unread = 0.
                    $unread = $lastSeen === null
                        ? 0
                        : $this->unreadCountFromTimestamp($patient->id, $lastSeen);

                    return [
                        'patient_id'   => $patient->id,
                        'patient_name' => $patient->name,
                        'last_message' => $lastMsg?->message,
                        'last_time'    => $lastMsg?->created_at->toIso8601String(),
                        'unread_count' => $unread,
                        'total_count'  => $total,
                    ];
                });

            return response(['conversations' => $conversations], 200);
        }

        if ($user->isPatient()) {
            $lastMsg = ChatMessage::where('patient_id', $user->id)
                ->orderBy('created_at', 'desc')
                ->first();

            $total = ChatMessage::where('patient_id', $user->id)->count();

            return response([
                'conversations' => [[
                    'patient_id'   => $user->id,
                    'patient_name' => $user->name,
                    'last_message' => $lastMsg?->message,
                    'last_time'    => $lastMsg?->created_at->toIso8601String(),
                    'unread_count' => $this->unreadCount($user->id, $user->id),
                    'total_count'  => $total,
                ]],
            ], 200);
        }

        if ($user->isCompanion()) {
            $patientIds = $user->patients()
                ->wherePivot('can_view_documents', true)
                ->pluck('users.id')
                ->toArray();

            $lastSeenMap = $this->getLastSeenBulk($user->id, $patientIds);

            $conversations = [];
            foreach ($patientIds as $patientId) {
                $patient = User::find($patientId);
                if (!$patient) continue;

                $lastMsg = ChatMessage::where('patient_id', $patientId)
                    ->orderBy('created_at', 'desc')
                    ->first();

                $total    = ChatMessage::where('patient_id', $patientId)->count();
                $lastSeen = $lastSeenMap[$patientId] ?? null;

                $conversations[] = [
                    'patient_id'   => $patientId,
                    'patient_name' => $patient->name,
                    'last_message' => $lastMsg?->message,
                    'last_time'    => $lastMsg?->created_at->toIso8601String(),
                    'unread_count' => $this->unreadCountFromTimestamp($patientId, $lastSeen),
                    'total_count'  => $total,
                ];
            }

            return response(['conversations' => $conversations], 200);
        }

        return response(['conversations' => []], 200);
    }

    // ─── Messages ────────────────────────────────────────────────────────────

    public function messages(Request $request)
    {
        $request->validate([
            'patient_id' => 'required|exists:users,id',
        ]);

        $user      = $request->user();
        $patientId = (int) $request->query('patient_id');

        if (!$this->canAccessConversation($user, $patientId)) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $messages = ChatMessage::where('patient_id', $patientId)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(fn($m) => $this->formatMessage($m));

        // Always stamp seen AFTER fetching — so the cursor lands past
        // all messages just returned, preventing them re-appearing as unread
        $this->markSeen($user->id, $patientId);

        return response(['messages' => $messages], 200);
    }

    // ─── Send ────────────────────────────────────────────────────────────────

    public function send(Request $request)
    {
        $request->validate([
            'patient_id' => 'required|exists:users,id',
            'message'    => 'required|string|max:2000',
        ]);

        $user      = $request->user();
        $patientId = (int) $request->input('patient_id');

        if (!$this->canAccessConversation($user, $patientId)) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $patient = User::findOrFail($patientId);
        if (!$patient->isPatient()) {
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

        // Sending = seeing, so your own message never counts against you
        $this->markSeen($user->id, $patientId);

        return response(['message' => $this->formatMessage($msg)], 201);
    }

    // ─── Private ─────────────────────────────────────────────────────────────

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