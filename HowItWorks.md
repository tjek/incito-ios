## What is incito
- json data from the graph or from a file
- defines the custom layout & rendering properties of a tree of views
- contains a list of font resources to download (.ttf files)
- layout/rendering properties basically match css

## Rendering steps
This is all platform agnostic (so could be run on tvOS or macOS etc):

- Download json from graph
	- takes a max-width - the width of the screen
	- this is not actually part of incito library - is in the SDK
	- all development was done with local files, for speed
- Parse json into a type-safe in-memory tree of view objects
	- I use a generic tree to store the tree of view elements (allows for reusable map functions)
	- Contains all the layout properties in (possibly) relative form (Eg. "width: 10%")
- Download all the font resources specified in the incito document
	- Load those fonts into the system, so that they can be used to size labels
	- I have a disk cache in front of the download to speed things up
- Convert the tree of relative view elements into a tree of absolutely sized/positioned view elements.
	- Depends on being provided with an initial width - the width of the screen
	- This is the complex, multi-pass layout code
	- Takes into account the systems text-renderer to calculate the size of labels - this is actually injected into the layout engine, so that it remains platform agnostic.


This is the iOS specific code:

- convert the tree of absolute layout properties into a tree of 'renderableViews'
	- These are 'lite' views. They contain the absolute position/size information of the view, the metadata about the view, a render callback that 'will do' the rendering into a native view, and the rendered view itself (which will be nil if not yet rendered, or if it has been unrendered when it stops being visible)
	- This RenderableTree is what is passed into the incito viewcontroller (the thing that has the scroll view). The incito is only considered 'loaded' (and we stop showing the spinner) once this renderable tree has been generated.
- Render the visible renderableViews
	- As the user scrolls we walk the renderable view tree from root to leaf, checking each lite-view to see if it's absolute frame is visible within the rendering window (the screen + a top/bottom margin). 
		- If a node is visible, we ask for its already rendered view. If that doesnt exist we call the render callback, generating and saving the view into the lite-view. We then do the same for all it's children, recursively, adding their rendered views to the parent's rendered view.
		- If a node is not visible, we unrender it (remove it's rendered view from memory), and unrender all its child nodes.
	- As we have the positions of all the renderable views, we can do things like ask what views are at any given location in the screen, even if they havnt been rendered.

