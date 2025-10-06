"use client";

import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Placeholder from "@tiptap/extension-placeholder";
import { useEffect } from "react";
import { cn } from "@/lib/utils";

interface TipTapEditorProps {
  content: string;
  onContentChange: (content: string) => void;
  editable?: boolean;
  placeholder?: string;
  className?: string;
}

export function TipTapEditor({
  content,
  onContentChange,
  editable = true,
  placeholder = "Start typing...",
  className,
}: TipTapEditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({
        placeholder,
      }),
    ],
    content,
    editable,
    onUpdate: ({ editor }) => {
      onContentChange(editor.getHTML());
    },
  });

  useEffect(() => {
    if (editor && content !== editor.getHTML()) {
      editor.commands.setContent(content);
    }
  }, [content, editor]);

  return (
    <div className={cn("rounded-md border", className)}>
      <EditorContent editor={editor} className="prose prose-sm max-w-none dark:prose-invert" />
    </div>
  );
}
