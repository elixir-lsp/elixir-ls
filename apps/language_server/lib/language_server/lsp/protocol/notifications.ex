# codegen: do not edit
defmodule GenLSP.Notifications do
  import Schematic

  def new(notification) do
    unify(
      oneof(fn
        %{"method" => "$/cancelRequest"} ->
          GenLSP.Notifications.DollarCancelRequest.schematic()

        %{"method" => "$/logTrace"} ->
          GenLSP.Notifications.DollarLogTrace.schematic()

        %{"method" => "$/progress"} ->
          GenLSP.Notifications.DollarProgress.schematic()

        %{"method" => "$/setTrace"} ->
          GenLSP.Notifications.DollarSetTrace.schematic()

        %{"method" => "exit"} ->
          GenLSP.Notifications.Exit.schematic()

        %{"method" => "initialized"} ->
          GenLSP.Notifications.Initialized.schematic()

        %{"method" => "notebookDocument/didChange"} ->
          GenLSP.Notifications.NotebookDocumentDidChange.schematic()

        %{"method" => "notebookDocument/didClose"} ->
          GenLSP.Notifications.NotebookDocumentDidClose.schematic()

        %{"method" => "notebookDocument/didOpen"} ->
          GenLSP.Notifications.NotebookDocumentDidOpen.schematic()

        %{"method" => "notebookDocument/didSave"} ->
          GenLSP.Notifications.NotebookDocumentDidSave.schematic()

        %{"method" => "telemetry/event"} ->
          GenLSP.Notifications.TelemetryEvent.schematic()

        %{"method" => "textDocument/didChange"} ->
          GenLSP.Notifications.TextDocumentDidChange.schematic()

        %{"method" => "textDocument/didClose"} ->
          GenLSP.Notifications.TextDocumentDidClose.schematic()

        %{"method" => "textDocument/didOpen"} ->
          GenLSP.Notifications.TextDocumentDidOpen.schematic()

        %{"method" => "textDocument/didSave"} ->
          GenLSP.Notifications.TextDocumentDidSave.schematic()

        %{"method" => "textDocument/publishDiagnostics"} ->
          GenLSP.Notifications.TextDocumentPublishDiagnostics.schematic()

        %{"method" => "textDocument/willSave"} ->
          GenLSP.Notifications.TextDocumentWillSave.schematic()

        %{"method" => "window/logMessage"} ->
          GenLSP.Notifications.WindowLogMessage.schematic()

        %{"method" => "window/showMessage"} ->
          GenLSP.Notifications.WindowShowMessage.schematic()

        %{"method" => "window/workDoneProgress/cancel"} ->
          GenLSP.Notifications.WindowWorkDoneProgressCancel.schematic()

        %{"method" => "workspace/didChangeConfiguration"} ->
          GenLSP.Notifications.WorkspaceDidChangeConfiguration.schematic()

        %{"method" => "workspace/didChangeWatchedFiles"} ->
          GenLSP.Notifications.WorkspaceDidChangeWatchedFiles.schematic()

        %{"method" => "workspace/didChangeWorkspaceFolders"} ->
          GenLSP.Notifications.WorkspaceDidChangeWorkspaceFolders.schematic()

        %{"method" => "workspace/didCreateFiles"} ->
          GenLSP.Notifications.WorkspaceDidCreateFiles.schematic()

        %{"method" => "workspace/didDeleteFiles"} ->
          GenLSP.Notifications.WorkspaceDidDeleteFiles.schematic()

        %{"method" => "workspace/didRenameFiles"} ->
          GenLSP.Notifications.WorkspaceDidRenameFiles.schematic()

        _ ->
          {:error, "unexpected notification payload"}
      end),
      notification
    )
  end
end
