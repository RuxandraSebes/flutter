<?php

namespace App\Http\Controllers;

use App\Models\Document;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class DocumentController extends Controller
{
    /**
     * List all documents belonging to the authenticated user.
     */
    public function index(Request $request)
    {
        $documents = Document::where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function ($doc) {
                return [
                    'id'         => $doc->id,
                    'name'       => $doc->name,
                    'url'        => Storage::url($doc->path),
                    'created_at' => $doc->created_at->toDateTimeString(),
                ];
            });

        return response(['documents' => $documents], 200);
    }

    /**
     * Upload a PDF document.
     */
    public function store(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:pdf|max:20480', // max 20MB
            'name' => 'nullable|string|max:255',
        ]);

        $file = $request->file('file');
        $name = $request->input('name') ?? $file->getClientOriginalName();

        // Store in storage/app/public/documents/{user_id}/
        $path = $file->store(
            'documents/' . $request->user()->id,
            'public'
        );

        $document = Document::create([
            'user_id' => $request->user()->id,
            'name'    => $name,
            'path'    => $path,
        ]);

        return response([
            'document' => [
                'id'         => $document->id,
                'name'       => $document->name,
                'url'        => Storage::url($path),
                'created_at' => $document->created_at->toDateTimeString(),
            ],
        ], 201);
    }

    /**
     * Delete a document.
     */
    public function destroy(Request $request, $id)
    {
        $document = Document::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        Storage::disk('public')->delete($document->path);
        $document->delete();

        return response(['message' => 'Document șters'], 200);
    }
}