#include "Scripts/Utilities/Sample.as"

String data = "[0: 122/568][1: 120/598][2: 119/628][3: 120/658][4: 124/688][5: 129/718][6: 136/748][7: 145/776][8: 156/804][9: 169/832][10: 183/858][11: 200/883][12: 218/908][13: 239/929][14: 264/945][15: 293/954][16: 322/956][17: 352/951][18: 380/941][19: 405/925][20: 428/906][21: 448/885][22: 467/861][23: 484/836][24: 498/809][25: 510/782][26: 520/753][27: 527/724][28: 533/695][29: 538/665][30: 541/635][31: 543/605][32: 544/575][33: 141/506][34: 166/475][35: 198/467][36: 232/470][37: 265/479][38: 348/476][39: 385/465][40: 423/461][41: 461/469][42: 493/502][43: 303/537][44: 301/569][45: 299/601][46: 298/633][47: 249/683][48: 276/684][49: 304/686][50: 330/683][51: 358/682][52: 169/550][53: 188/540][54: 231/538][55: 248/549][56: 228/554][57: 188/556][58: 368/547][59: 388/535][60: 435/538][61: 456/548][62: 434/554][63: 389/552][64: 167/500][65: 198/494][66: 231/495][67: 264/499][68: 349/497][69: 385/492][70: 423/490][71: 460/495][72: 210/536][73: 208/557][74: 209/547][75: 412/534][76: 411/556][77: 412/546][78: 275/543][79: 335/542][80: 253/627][81: 354/626][82: 235/661][83: 372/660][84: 223/794][85: 242/760][86: 271/740][87: 306/743][88: 339/741][89: 367/763][90: 387/793][91: 369/828][92: 342/854][93: 304/863][94: 266/856][95: 239/830][96: 235/793][97: 266/772][98: 305/768][99: 343/771][100: 375/792][101: 344/812][102: 306/821][103: 267/814][104: 209/547][105: 412/546]";


Array<Vector2> points;

Array<Vector2> ReadPoints(const String&in txt)
{
    Array<Vector2> ret;
    Vector2 v;
    int state = 0;
    String x_str, y_str;
    for (uint i=0; i<txt.length; ++i)
    {
        uint8 c = txt[i];
        if (c == ':')
        {
            state = 1;
            x_str = "";
            y_str = "";
        }
        else if (c == '/')
        {
            state = 2;
        }
        else
        {
            if (state == 1)
            {
                if (c != ' ')
                {
                    x_str.AppendUTF8(c);
                }
            }
            else if (state == 2)
            {
                y_str.AppendUTF8(c);

                if (c == ']')
                {
                    state = 0;
                    v.x = x_str.ToFloat();
                    v.y = y_str.ToFloat();
                    ret.Push(v);
                    // Print("Add pos=" + v.ToString());
                }
            }
        }
    }

    return ret;
}

void Start()
{
    points = ReadPoints(data);

    // Execute the common startup for samples
    SampleStart();

    // Create the scene content
    CreateScene();

    // Create the UI content and subscribe to UI events
    CreateUI();

    // Setup the viewport for displaying the scene
    SetupViewport();

    // Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_RELATIVE);

    // Subscribe to global events for camera movement
    SubscribeToEvents();
}

void CreateScene()
{
    scene_ = Scene();

    // Load scene content prepared in the editor (XML format). GetFile() returns an open file from the resource system
    // which scene.LoadXML() will read
    scene_.LoadXML(cache.GetFile("Scenes/Head.xml"));

    // Create the camera (not included in the scene file)
    cameraNode = scene_.CreateChild("Camera");
    cameraNode.CreateComponent("Camera");

    // Set an initial position for the camera scene node above the plane
    cameraNode.position = Vector3(0.0f, 0.5f, -1.0f);
}

void CreateUI()
{
    // Set up global UI style into the root UI element
    XMLFile@ style = cache.GetResource("XMLFile", "UI/DefaultStyle.xml");
    ui.root.defaultStyle = style;

    // Create a Cursor UI element because we want to be able to hide and show it at will. When hidden, the mouse cursor will
    // control the camera, and when visible, it will interact with the UI
    Cursor@ cursor = Cursor();
    cursor.SetStyleAuto();
    ui.cursor = cursor;
    // Set starting position of the cursor at the rendering window center
    cursor.SetPosition(graphics.width / 2, graphics.height / 2);

    // Load UI content prepared in the editor and add to the UI hierarchy
    UIElement@ layoutRoot = ui.LoadLayout(cache.GetResource("XMLFile", "UI/UILoadExample.xml"));
    ui.root.AddChild(layoutRoot);

    // Subscribe to button actions (toggle scene lights when pressed then released)
    Button@ button = layoutRoot.GetChild("ToggleLight1", true);
    if (button !is null)
        SubscribeToEvent(button, "Released", "ToggleLight1");
    button = layoutRoot.GetChild("ToggleLight2", true);
    if (button !is null)
        SubscribeToEvent(button, "Released", "ToggleLight2");
}

void ToggleLight1()
{
    Node@ lightNode = scene_.GetChild("Light1", true);
    if (lightNode !is null)
        lightNode.enabled = !lightNode.enabled;
}

void ToggleLight2()
{
    Node@ lightNode = scene_.GetChild("Light2", true);
    if (lightNode !is null)
        lightNode.enabled = !lightNode.enabled;
}

void SetupViewport()
{
    // Set up a viewport to the Renderer subsystem so that the 3D scene can be seen
    Viewport@ viewport = Viewport(scene_, cameraNode.GetComponent("Camera"));
    renderer.viewports[0] = viewport;
}

void SubscribeToEvents()
{
    SubscribeToEvent("Update", "HandleUpdate");
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate");
}

void HandleUpdate(StringHash eventType, VariantMap& eventData)
{
    // Take the frame time step, which is stored as a float
    float timeStep = eventData["TimeStep"].GetFloat();
    // Move the camera, scale movement with time step
    MoveCamera(timeStep);
}

void MoveCamera(float timeStep)
{
    input.mouseVisible = input.mouseMode != MM_RELATIVE;
    bool mouseDown = input.mouseButtonDown[MOUSEB_RIGHT];

    // Override the MM_RELATIVE mouse grabbed settings, to allow interaction with UI
    input.mouseGrabbed = mouseDown;

    // Right mouse button controls mouse cursor visibility: hide when pressed
    ui.cursor.visible = !mouseDown;

    // Do not move if the UI has a focused element
    if (ui.focusElement !is null)
        return;

    // Movement speed as world units per second
    const float MOVE_SPEED = 20.0f;
    // Mouse sensitivity as degrees per pixel
    const float MOUSE_SENSITIVITY = 0.1f;

    // Use this frame's mouse motion to adjust camera node yaw and pitch. Clamp the pitch between -90 and 90 degrees
    // Only move the camera when the cursor is hidden
    if (!ui.cursor.visible)
    {
        IntVector2 mouseMove = input.mouseMove;
        yaw += MOUSE_SENSITIVITY * mouseMove.x;
        pitch += MOUSE_SENSITIVITY * mouseMove.y;
        pitch = Clamp(pitch, -90.0f, 90.0f);

        // Construct new orientation for the camera scene node from yaw and pitch. Roll is fixed to zero
        cameraNode.rotation = Quaternion(pitch, yaw, 0.0f);
    }

    // Read WASD keys and move the camera scene node to the corresponding direction if they are pressed
    if (input.keyDown[KEY_W])
        cameraNode.Translate(Vector3(0.0f, 0.0f, 1.0f) * MOVE_SPEED * timeStep);
    if (input.keyDown[KEY_S])
        cameraNode.Translate(Vector3(0.0f, 0.0f, -1.0f) * MOVE_SPEED * timeStep);
    if (input.keyDown[KEY_A])
        cameraNode.Translate(Vector3(-1.0f, 0.0f, 0.0f) * MOVE_SPEED * timeStep);
    if (input.keyDown[KEY_D])
        cameraNode.Translate(Vector3(1.0f, 0.0f, 0.0f) * MOVE_SPEED * timeStep);
}

void HandlePostRenderUpdate()
{
    DebugRenderer@ debug = scene_.debugRenderer;
}

// Create XML patch instructions for screen joystick layout specific to this sample app
String patchInstructions = "";