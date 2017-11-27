// ==============================================
//
//    GameObject Base Class
//
// ==============================================

const int CTRL_ATTACK = (1 << 0);
const int CTRL_JUMP = (1 << 1);
const int CTRL_ALL = (1 << 16);

const uint FLAGS_ATTACK  = (1 << 0);
const uint FLAGS_COUNTER = (1 << 1);
const uint FLAGS_NO_MOVE = (1 << 2);
const uint FLAGS_MOVING = (1 << 3);
const uint FLAGS_INVINCIBLE = (1 << 4);
const uint FLAGS_STUN = (1 << 5);
const uint FLAGS_KEEP_DIST = (1 << 6);
const uint FLAGS_RUN_TO_ATTACK = (1 << 7);
const uint FLAGS_DEAD = (1 << 8);

const uint COLLISION_LAYER_LANDSCAPE = (1 << 0);
const uint COLLISION_LAYER_CHARACTER = (1 << 1);
const uint COLLISION_LAYER_PROP      = (1 << 2);
const uint COLLISION_LAYER_RAGDOLL   = (1 << 3);

class GameObject : ScriptObject
{
    float   duration = -1;
    uint    flags = 0;
    int     side = 0;
    float   timeScale = 1.0f;

    void SetTimeScale(float scale)
    {
        timeScale = scale;
        LogPrint(GetName() + " SetTimeScale:" + scale);
    }

    void FixedUpdate(float timeStep)
    {
        timeStep *= timeScale;
        CheckDuration(timeStep);
    }

    void CheckDuration(float timeStep)
    {
        // Disappear when duration expired
        if (duration >= 0)
        {
            duration -= timeStep;
            if (duration <= 0)
                Remove();
        }
    }

    void Update(float timeStep)
    {
        timeStep *= timeScale;
    }

    void PlaySound(const String&in soundName)
    {
        // Create the sound channel
        SoundSource3D@ source = GetNode().CreateComponent("SoundSource3D");
        //SoundSource@ source = GetNode().CreateComponent("SoundSource");
        Sound@ sound = cache.GetResource("Sound", soundName);
        source.SetDistanceAttenuation(5, 50, 2);
        source.Play(sound);
        source.soundType = SOUND_EFFECT;
        source.frequency = source.frequency * GetNode().scene.timeScale; // * timeScale;
        // Subscribe to sound finished for cleaning up the source
        SubscribeToEvent(node, "SoundFinished", "HandleSoundFinished");
    }

    void HandleSoundFinished(StringHash eventType, VariantMap& eventData)
    {
        SoundSource3D@ source = eventData["SoundSource"].GetPtr();
        source.Remove();
    }

    void DebugDraw(DebugRenderer@ debug)
    {

    }

    String GetDebugText()
    {
        return "";
    }

    String GetName()
    {
        return "";
    }

    void Reset()
    {

    }

    bool OnDamage(GameObject@ attacker, const Vector3&in position, const Vector3&in direction, int damage, bool weak = false)
    {
        return true;
    }

    Node@ GetNode()
    {
        return null;
    }

    Scene@ GetScene()
    {
        Node@ _node = GetNode();
        if (_node is null)
            return null;
        return _node.scene;
    }

    void SetSceneTimeScale(float scale)
    {
        Scene@ _scene = GetScene();
        if (_scene is null)
            return;
        if (_scene.timeScale == scale)
            return;
        _scene.timeScale = scale;
        gGame.OnSceneTimeScaleUpdated(_scene, scale);
        LogPrint(GetName() + " SetSceneTimeScale:" + scale);
    }

    void Transform(const Vector3& pos, const Quaternion& qua)
    {
        Node@ _node = GetNode();
        _node.worldPosition = FilterPosition(pos);
        _node.worldRotation = qua;
    }

    void Remove()
    {
        // LogPrint(node.name + ".Remove()");
        node.Remove();
    }

    bool IsVisible()
    {
        return true;
    }

    bool HasFlag(uint flag)
    {
        return Global_HasFlag(flags, flag);
    }

    void AddFlag(uint flag)
    {
        flags = Global_AddFlag(flags, flag);
        UpdateOnFlagsChanged();
    }

    void RemoveFlag(uint flag)
    {
        flags = Global_RemoveFlag(flags, flag);
        UpdateOnFlagsChanged();
    }

    void UpdateOnFlagsChanged()
    {
    }
};

void SetWorldTimeScale(Scene@ _scene, float scale)
{
    LogPrint("SetWorldTimeScale:" + scale);
    Array<Node@> nodes = _scene.GetChildrenWithScript(false);
    for (uint i=0; i<nodes.length; ++i)
    {
        GameObject@ object = cast<GameObject>(nodes[i].scriptObject);
        if (object is null)
            continue;
        object.SetTimeScale(scale);
    }
}

Vector3 FilterPosition(const Vector3&in position)
{
    float x = position.x;
    float z = position.z;
    float radius = COLLISION_RADIUS + 1.0f;
    x = Clamp(x, radius - WORLD_HALF_SIZE.x, WORLD_HALF_SIZE.x - radius);
    z = Clamp(z, radius - WORLD_HALF_SIZE.z, WORLD_HALF_SIZE.z - radius);
    return Vector3(x, position.y, z);
}