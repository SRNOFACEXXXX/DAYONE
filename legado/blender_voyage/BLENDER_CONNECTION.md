# Live Blender connection — verified

The installed Blender MCP addon is listening on localhost:9876 in Blender 4.5.13 LTS. The local client `blender_bridge_client.py` speaks the addon's observed null-delimited JSON protocol. This is direct access to the MCP addon's bridge, not a separately registered MCP tool in this task.

Verified read response: Blender version, current workspace, scene object names and types, current file. The bridge supports querying further scene data explicitly; it does not continuously stream the entire workspace to the assistant.

Verified write: created new scene `Voyage | Reconstruction 03` and saved `voyage_rebuild_v3.blend`. Original/default scene data and earlier rejected files were preserved.

Visual control: Computer Use `@oai/sky` can identify and activate the Blender window. Its Windows.Graphics.Capture screenshot path is incompatible with this Windows 10 build. The user explicitly authorized Python screenshot capture as an alternative. `capture_blender.py` uses Pillow ImageGrab on the Blender client rectangle and does not send any input. Blender must be foreground; occluding windows can otherwise appear in the capture.

Current model is work in progress, not a certified photorealistic/AAA asset. The first viewport review revealed panel corner gaps and glass/trim overlap. A correction script has been prepared. Further silhouette and detail review is required.
