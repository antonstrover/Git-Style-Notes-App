import { render, screen } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { TipTapEditor } from "@/components/editor/tiptap-editor";

describe("TipTapEditor", () => {
  it("renders with placeholder", () => {
    const onContentChange = vi.fn();

    render(
      <TipTapEditor content="" onContentChange={onContentChange} placeholder="Test placeholder" />
    );

    // TipTap renders the placeholder via CSS, check for the editor container
    const editor = document.querySelector(".ProseMirror");
    expect(editor).toBeInTheDocument();
  });

  it("renders with initial content", () => {
    const onContentChange = vi.fn();
    const initialContent = "Hello World";

    render(<TipTapEditor content={initialContent} onContentChange={onContentChange} />);

    const editor = document.querySelector(".ProseMirror");
    expect(editor).toBeInTheDocument();
    expect(editor?.textContent).toContain(initialContent);
  });

  it("applies custom className", () => {
    const onContentChange = vi.fn();

    render(
      <TipTapEditor
        content=""
        onContentChange={onContentChange}
        className="custom-class"
      />
    );

    const container = document.querySelector(".custom-class");
    expect(container).toBeInTheDocument();
  });
});
