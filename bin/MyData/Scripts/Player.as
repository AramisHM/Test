
const float fullTurnThreashold = 125;
const float attackRadius = 3;

class PlayerStandState : CharacterState
{
    Array<String>           animations;

    PlayerStandState(Character@ c)
    {
        super(c);
        name = "StandState";
        animations.Push(GetAnimationName("BM_Combat_Movement/Stand_Idle"));
        animations.Push(GetAnimationName("BM_Combat_Movement/Stand_Idle_01"));
        animations.Push(GetAnimationName("BM_Combat_Movement/Stand_Idle_02"));
    }

    void Enter(State@ lastState)
    {
        PlayAnimation(ownner.animCtrl, animations[RandomInt(animations.length)], LAYER_MOVE, true, 0.5);
    }

    void Exit(State@ nextState)
    {
        CharacterState::Exit(nextState);

    /*
        Vector3 leftFootPos = ownner.sceneNode.GetChild("Bip01_L_Foot", true).worldPosition;
        Vector3 rightFootPos = ownner.sceneNode.GetChild("Bip01_R_Foot", true).worldPosition;
        Vector3 diff = leftFootPos - rightFootPos;
        diff.y = 0;
        Print("Distance from left foot to right foot is " + String(diff.length));
    */
    }

    void Update(float dt)
    {
        if (!gInput.IsLeftStickInDeadZone() && gInput.IsLeftStickStationary())
        {
            int index = RadialSelectAnimation_Player(ownner.sceneNode, 4);
            ownner.sceneNode.vars["AnimationIndex"] = index;
            if (index == 0)
                ownner.stateMachine.ChangeState("MoveState");
            else
                ownner.stateMachine.ChangeState("StandToMoveState");
        }

        if (gInput.IsAttackPressed())
            ownner.Attack();
        else if(gInput.IsCounterPressed())
            ownner.Counter();

        CharacterState::Update(dt);
    }
};

class PlayerStandToMoveState : MultiMotionState
{
    float turnSpeed;

    PlayerStandToMoveState(Character@ c)
    {
        super(c);
        name = "StandToMoveState";
        motions.Push(gMotionMgr.FindMotion("BM_Combat_Movement/Turn_Right_90"));
        motions.Push(gMotionMgr.FindMotion("BM_Combat_Movement/Turn_Right_180"));
        motions.Push(gMotionMgr.FindMotion("BM_Combat_Movement/Turn_Left_90"));
        turnSpeed = 5;
    }

    void Update(float dt)
    {
        float characterDifference = ComputeDifference_Player(ownner.sceneNode);
        float a = timeInState / motions[selectIndex].endTime;
        float dYaw = characterDifference * turnSpeed * dt * a;
        //motions[selectIndex].startRotation += dYaw;

        if ( (Abs(characterDifference) > fullTurnThreashold) && gInput.IsLeftStickStationary() )
        {
            Print("180!!!");
            ownner.stateMachine.ChangeState("MoveTurn180State");
        }

        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
        {
            if (gInput.IsLeftStickInDeadZone() && gInput.HasLeftStickBeenStationary(0.1))
                ownner.stateMachine.ChangeState("StandState");
            else
                ownner.stateMachine.ChangeState("MoveState");
        }

        CharacterState::Update(dt);
    }

    int PickIndex()
    {
        return ownner.sceneNode.vars["AnimationIndex"].GetInt() - 1;
    }
};

class PlayerMoveState : CharacterState
{
    Motion@ motion;
    float turnSpeed;

    PlayerMoveState(Character@ c)
    {
        super(c);
        name = "MoveState";
        @motion = gMotionMgr.FindMotion("BM_Combat_Movement/Walk_Forward");
        turnSpeed = 5;
    }

    void Update(float dt)
    {
        // check if we should return to the idle state
        if (gInput.IsLeftStickInDeadZone() && gInput.HasLeftStickBeenStationary(0.1))
            ownner.stateMachine.ChangeState("StandState");

        // compute the difference between the direction the character is facing
        // and the direction the user wants to go in
        float characterDifference = ComputeDifference_Player(ownner.sceneNode)  ;

        // if the difference is greater than this about, turn the character
        ownner.sceneNode.Yaw(characterDifference * turnSpeed * dt);
        motion.Move(dt, ownner.sceneNode, ownner.animCtrl);

        bool evade = gInput.IsEvadePressed();

        // if the difference is large, then turn 180 degrees
        if ( (Abs(characterDifference) > fullTurnThreashold) && gInput.IsLeftStickStationary() )
        {
            Print("180!!!");
            if (evade) {
                ownner.sceneNode.vars["AnimationIndex"] = 1;
                ownner.stateMachine.ChangeState("EvadeState");
            }
            else
                ownner.stateMachine.ChangeState("MoveTurn180State");
        }

        if(evade) {
            ownner.sceneNode.vars["AnimationIndex"] = 0;
            ownner.stateMachine.ChangeState("EvadeState");
        }

        CharacterState::Update(dt);
    }

    void Enter(State@ lastState)
    {
        PlayerStandToMoveState@ standToMoveState = cast<PlayerStandToMoveState@>(lastState);
        motion.Start(ownner.sceneNode, ownner.animCtrl, 0.0, 0.2);
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        motion.DebugDraw(debug, ownner.sceneNode);
    }
};

class PlayerMoveTurn180State : CharacterState
{
    Motion@ motion;

    PlayerMoveTurn180State(Character@ c)
    {
        super(c);
        name = "MoveTurn180State";
        @motion = gMotionMgr.FindMotion("BM_Combat_Movement/Turn_Right_180");
    }

    void Update(float dt)
    {
        if (motion.Move(dt, ownner.sceneNode, ownner.animCtrl))
            ownner.CommonStateFinishedOnGroud();

        CharacterState::Update(dt);
    }

    void Enter(State@ lastState)
    {
        motion.Start(ownner.sceneNode, ownner.animCtrl, 0.0f, 0.1f);
    }
};

class PlayerEvadeState : MultiMotionState
{
    PlayerEvadeState(Character@ c)
    {
        super(c);
        name = "EvadeState";
        motions.Push(gMotionMgr.FindMotion("BM_Movement/Evade_Forward_01"));
        motions.Push(gMotionMgr.FindMotion("BM_Movement/Evade_Back_01"));
    }

    void Update(float dt)
    {
        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
            ownner.CommonStateFinishedOnGroud();

        MultiMotionState::Update(dt);
    }

    int PickIndex()
    {
        return ownner.sceneNode.vars["AnimationIndex"].GetInt();
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        motions[selectIndex].DebugDraw(debug, ownner.sceneNode);
    }
};

class PlayerAlignState : CharacterAlignState
{
    PlayerAlignState(Character@ c)
    {
        super(c);
    }
};

class PlayerAttackState : CharacterState
{
    Array<AttackMotion@>  forwardAttacks;
    Array<AttackMotion@>  leftAttacks;
    Array<AttackMotion@>  rightAttacks;
    Array<AttackMotion@>  backAttacks;

    float           fixRotatePerSec;

    AttackMotion@    currentAttack;

    Enemy@          attackEnemy;

    int             debugStatus;

    PlayerAttackState(Character@ c)
    {
        super(c);
        name = "AttackState";

        String preFix = "BM_Attack/";
        // forward close
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_02", 14));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_03", 12));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_04", 19));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_05", 24));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_06", 20));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_07", 19));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Close_Forward_08", 18));
        // forward far
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Far_Forward", 24));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Far_Forward_01", 17));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Far_Forward_02", 21));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Far_Forward_03", 22));
        forwardAttacks.Push(AttackMotion(preFix + "Attack_Far_Forward_04", 22));

        // right close
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right", 16));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_01", 18));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_03", 11));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_04", 19));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_05", 15));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_06", 21));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_07", 16));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Close_Right_08", 18));

        // right far
        rightAttacks.Push(AttackMotion(preFix + "Attack_Far_Right", 25));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Far_Right_01", 15));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Far_Right_02", 21));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Far_Right_03", 29));
        rightAttacks.Push(AttackMotion(preFix + "Attack_Far_Right_04", 22));

        // left close
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left", 7));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_01", 18));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_02", 13));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_03", 21));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_04", 22));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_05", 15));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_06", 17));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_07", 15));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Close_Left_08", 20));

        // left far
        leftAttacks.Push(AttackMotion(preFix + "Attack_Far_Left", 19));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Far_Left_01", 23));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Far_Left_02", 22));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Far_Left_03", 21));
        leftAttacks.Push(AttackMotion(preFix + "Attack_Far_Left_04", 23));

        // back close
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back", 9));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_01", 16));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_02", 18));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_03", 21));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_04", 14));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_05", 14));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_06", 15));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_07", 14));
        backAttacks.Push(AttackMotion(preFix + "Attack_Close_Back_08", 17));

        // back far
        backAttacks.Push(AttackMotion(preFix + "Attack_Far_Back", 14));
        backAttacks.Push(AttackMotion(preFix + "Attack_Far_Back_01", 15));
        backAttacks.Push(AttackMotion(preFix + "Attack_Far_Back_02", 18));
        backAttacks.Push(AttackMotion(preFix + "Attack_Far_Back_03", 23));
        backAttacks.Push(AttackMotion(preFix + "Attack_Far_Back_04", 20));
    }

    ~PlayerAttackState()
    {
        @attackEnemy = null;
        @currentAttack = null;
    }

    void Update(float dt)
    {
        if (currentAttack is null)
            return;

        Motion@ motion = currentAttack.motion;
        if (ownner.animCtrl.GetTime(motion.animationName) >= currentAttack.impactTime && debugStatus == 0) {
            debugStatus = 1;
            ownner.animCtrl.SetSpeed(motion.animationName, 0.0f);
        }
        if (debugStatus == 0)
        {
            motion.startRotation += fixRotatePerSec * dt;
            // Print("motion.startRotation=" + String(motion.startRotation));
        }

        if (motion.Move(dt, ownner.sceneNode, ownner.animCtrl)) {
            ownner.stateMachine.ChangeState("StandState");
        }

        if (input.keyPress['F'] && debugStatus == 1) {
            ownner.animCtrl.SetSpeed(motion.animationName, 1.0f);
            // ownner.stateMachine.ChangeState("StandState");
        }

        CharacterState::Update(dt);
    }

    AttackMotion@ GetAttack(int dir, int index)
    {
        if (dir == 0)
            return forwardAttacks[index];
        else if (dir == 1)
            return rightAttacks[index];
        else if (dir == 2)
            return backAttacks[index];
        else
            return leftAttacks[index];
    }

    void PickBestMotion(const Array<AttackMotion@>&in attacks)
    {
        Vector3 myPos = ownner.sceneNode.worldPosition;
        Vector3 enemyPos = attackEnemy.sceneNode.worldPosition;
        Vector3 enemyToMePos = enemyPos - myPos;

        Quaternion myRot = ownner.sceneNode.worldRotation;
        float yaw = myRot.eulerAngles.y;
        Vector3 impactPosDiff;
        float distFromEnemyToMeSQR = enemyToMePos.lengthSquared;

        float minDistSQR = 99999;
        int bestIndex = -1;
        for (uint i=0; i<attacks.length; ++i)
        {
            AttackMotion@ attack = attacks[i];
            Vector3 imp = attack.impactPosition;
            imp.y = 0;
            Vector3 impactPos = myPos + myRot * imp;
            Vector3 diff = enemyPos - impactPos;
            diff.y = 0;
            float distSQR = diff.lengthSquared;
            if (distSQR < minDistSQR)
            {
                bestIndex = i;
                minDistSQR = distSQR;
                impactPosDiff = diff;
            }
        }

        if (bestIndex < 0) {
            Print("bestIndex is -1 !!!");
            return;
        }

        @currentAttack = attacks[bestIndex];
        float diffAngle = Atan2(impactPosDiff.x, impactPosDiff.z);

        Print("Best attack motion = " + String(currentAttack.motion.animationName) +
              " minDistSQR=" + String(minDistSQR) +
              " diffAngle=" + String(diffAngle));
    }

    void Enter(State@ lastState)
    {
        fixRotatePerSec = 0;

        Vector3 myPos = ownner.sceneNode.worldPosition;
        Vector3 enemyPos = attackEnemy.sceneNode.worldPosition;
        Vector3 posDiff = enemyPos - myPos;
        posDiff.y = 0;
        Quaternion myRot = ownner.sceneNode.worldRotation;

        float angle = Atan2(posDiff.x, posDiff.z);
        int r = RadialSelectAnimation(ownner.sceneNode, 4, angle);
        Print("Attack-align pos-diff=" + posDiff.ToString() + " r-index=" + String(r) + " angle=" + String(angle));
        float targetAngle = 0;

        int i = 0;
        if (r == 0)
        {
            PickBestMotion(forwardAttacks);
            targetAngle = 0;
        }
        else if (r == 1)
        {
            PickBestMotion(rightAttacks);
            targetAngle = 90;
        }
        else if (r == 2)
        {
            PickBestMotion(backAttacks);
            targetAngle = angle < 0 ? -180 : 180;
        }
        else if (r == 3)
        {
            PickBestMotion(leftAttacks);
            targetAngle = -90;
        }

        if (currentAttack is null)
            return;

        float a_diff = angleDiff(targetAngle - angle);
        fixRotatePerSec = a_diff / currentAttack.impactTime;
        Print("targetAngle=" + String(targetAngle) + " a_diff=" + String(a_diff) + " fixRotatePerSec=" + String(fixRotatePerSec));


        currentAttack.motion.Start(ownner.sceneNode, ownner.animCtrl);
        debugStatus = 0;
    }

    void Exit(State@ nextState)
    {
        CharacterState::Exit(nextState);
        @attackEnemy = null;
        @currentAttack = null;
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        if (currentAttack is null)
            return;
        currentAttack.motion.DebugDraw(debug, ownner.sceneNode);
        debug.AddLine(currentAttack.motion.startPosition, currentAttack.motion.GetFuturePosition(currentAttack.impactTime), Color(0.25f, 0.25f, 0.75f), false);
        debug.AddLine(ownner.sceneNode.worldPosition, attackEnemy.sceneNode.worldPosition, Color(0.25f, 0.75f, 0.25f), false);
    }
};


class PlayerCounterState : CharacterState
{
    Array<Motion@>      motions;
    Enemy@              counterEnemy;
    int                 status;
    Vector3             positionDiff;
    float               rotationDiff;
    int                 counterIndex;
    float               alignTime;

    PlayerCounterState(Character@ c)
    {
        super(c);
        name = "CounterState";
        motions.Push(gMotionMgr.FindMotion("BM_TG_Counter/Counter_Arm_Front_01"));
        alignTime = 0.2f;
    }

    ~PlayerCounterState()
    {
        @counterEnemy = null;
    }

    void Update(float dt)
    {
        if (status == 0) {
            // aligning
            float targetRotation = counterEnemy.sceneNode.worldRotation.eulerAngles.y + rotationDiff;
            Vector3 targetPos = Quaternion(0, targetRotation, 0) * positionDiff + node.worldPosition;
            targetPos = node.worldPosition.Lerp(targetPos, timeInState/alignTime);
            float curRot = node.worldRotation.eulerAngles.y;
            float dYaw = angleDiff(targetRotation - curRot);
            float timeLeft = alignTime - timeInState;
            float yawPerSec = dYaw / timeLeft;
            node.worldRotation = Quaternion(0, curRot + yawPerSec * dt, 0);

            if (timeInState >= alignTime) {
                Print("FINISHED ALIGN!!!!");
                status = 1;
                counterEnemy.sceneNode.vars["CounterIndex"] = counterIndex;
                counterEnemy.stateMachine.ChangeState("CounterState");
                motions[counterIndex].Start(ownner.sceneNode, ownner.animCtrl);
            }
        }
        else {
            // real counting
            if (motions[counterIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
                ownner.stateMachine.ChangeState("StandState");
        }

        CharacterState::Update(dt);
    }

    void Enter(State@ lastState)
    {
        status = 0;
        Vector3 myPos = ownner.sceneNode.worldPosition;
        Vector3 myDir = ownner.sceneNode.worldRotation * Vector3(0, 0, 1);
        float myAngle = Atan2(myDir.x, myDir.z);
        Vector3 enemyPos = counterEnemy.sceneNode.worldPosition;
        Vector3 posDiff = enemyPos - myPos;
        posDiff.y = 0;

        float angle = Atan2(posDiff.x, posDiff.z);
        float dAngle = angleDiff(angle - myAngle);
        int front_back = 0;
        if (Abs(dAngle) > 90)
            front_back = 1;
        rotationDiff = (front_back == 0) ? 180 : 0;
        Print("Counter-align pod-diff=" + posDiff.ToString() + " angle-diff=" + String(dAngle));

        counterIndex = 0; // FIXME TODO
        ThugCounterState@ enemyCounterState = cast<ThugCounterState@>(counterEnemy.stateMachine.FindState("CounterState"));
        if (enemyCounterState is null)
            return;

        positionDiff = motions[counterIndex].startFromOrigin - enemyCounterState.motions[counterIndex].startFromOrigin;
        Print("positionDiff=" + positionDiff.ToString() + " rotationDiff=" + String(rotationDiff));
    }

    void Exit(State@ nextState)
    {
        CharacterState::Exit(nextState);
        @counterEnemy = null;
    }
};

class PlayerHitState : MultiMotionState
{
    PlayerHitState(Character@ c)
    {
        super(c);
        name = "HitState";
    }

    void Update(float dt)
    {
        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
            ownner.stateMachine.ChangeState("StandState");

        CharacterState::Update(dt);
    }

    void Enter(State@ lastState)
    {
        MultiMotionState::Enter(lastState);
    }

    int PickIndex()
    {
        return ownner.sceneNode.vars["Hit"].GetInt();
    }
};

class Player : Character
{
    float maxAttackDistSQR;
    float maxCounterDistSQR;
    int combo;

    Player()
    {
        super();
        combo = 0;
        maxAttackDistSQR = 100.f * 100.0f;
        maxCounterDistSQR = 3.0f * 3.0f;
    }

    void Start()
    {
        uint startTime = time.systemTime;
        Character::Start();
        stateMachine.AddState(PlayerStandState(this));
        stateMachine.AddState(PlayerStandToMoveState(this));
        stateMachine.AddState(PlayerMoveState(this));
        stateMachine.AddState(PlayerMoveTurn180State(this));
        stateMachine.AddState(PlayerAttackState(this));
        stateMachine.AddState(PlayerAlignState(this));
        stateMachine.AddState(PlayerCounterState(this));
        stateMachine.AddState(PlayerEvadeState(this));
        stateMachine.AddState(PlayerHitState(this));
        stateMachine.ChangeState("StandState");
        Print("Player::Start time-cose=" + String(time.systemTime - startTime) + " ms");
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        debug.AddNode(sceneNode, 1.0f, false);
        debug.AddNode(sceneNode.GetChild("Bip01", true), 1.0f, false);
        /*
        Vector3 fwd = Vector3(0, 0, 1);
        Vector3 camDir = cameraNode.worldRotation * fwd;
        float cameraAngle = Atan2(camDir.x, camDir.z);
        Vector3 characterDir = sceneNode.worldRotation * fwd;
        float characterAngle = Atan2(characterDir.x, characterDir.z);
        float targetAngle = cameraAngle + gInput.m_leftStickAngle;
        float baseLen = 2.0f;
        DebugDrawDirection(debug, sceneNode, targetAngle, Color(1, 1, 0), baseLen);
        DebugDrawDirection(debug, sceneNode, characterAngle, Color(1, 0, 1), baseLen);
        */
        Character::DebugDraw(debug);
    }

    void Attack()
    {
        // Find the best enemy
        Vector3 myPos = sceneNode.worldPosition;
        Vector3 myDir = sceneNode.worldRotation * Vector3(0, 0, 1);
        float myAngle = Atan2(myDir.x, myDir.z);
        Vector3 camDir = cameraNode.worldRotation * Vector3(0, 0, 1);
        float cameraAngle = Atan2(camDir.x, camDir.z);
        float targetAngle = gInput.m_leftStickAngle + cameraAngle;
        gEnemyMgr.scoreCache.Clear();

        Enemy@ attackEnemy = null;
        Print("Attack targetAngle=" + String(targetAngle));

        for (uint i=0; i<gEnemyMgr.enemyList.length; ++i)
        {
            Enemy@ e = gEnemyMgr.enemyList[i];
            Vector3 posDiff = e.sceneNode.worldPosition - myPos;
            posDiff.y = 0;
            int score = 0;
            float distSQR = posDiff.lengthSquared;
            Print(String(distSQR));
            if (distSQR > maxAttackDistSQR || !e.CanBeAttacked())
            {
                gEnemyMgr.scoreCache.Push(-1);
                continue;
            }
            float diffAngle = Abs(Atan2(posDiff.x, posDiff.z));
            int angleScore = (180 - diffAngle)/180 * 50; // angle at 50% percant
            score += angleScore;
            gEnemyMgr.scoreCache.Push(score);
            Print("Enemy " + e.sceneNode.name + " distSQR=" + String(distSQR) + " diffAngle=" + String(diffAngle) + " score=" + String(score));
        }

        int bestScore = 0;
        for (uint i=0; i<gEnemyMgr.scoreCache.length;++i)
        {
            int score = gEnemyMgr.scoreCache[i];
            if (score >= bestScore) {
                bestScore = score;
                @attackEnemy = gEnemyMgr.enemyList[i];
            }
        }

        if (attackEnemy is null)
            return;

        Print("Choose Attack Enemy " + attackEnemy.sceneNode.name);
        PlayerAttackState@ state = cast<PlayerAttackState@>(stateMachine.FindState("AttackState"));
        if (state is null)
            return;
        @state.attackEnemy = attackEnemy;
        stateMachine.ChangeState("AttackState");
    }

    void Counter()
    {
        Vector3 myPos = sceneNode.worldPosition;
        Vector3 myDir = sceneNode.worldRotation * Vector3(0, 0, 1);
        float myAngle = Atan2(myDir.x, myDir.z);
        float curDistSQR = 999999;
        Vector3 curPosDiff;

        Enemy@ counterEnemy = null;

        for (uint i=0; i<gEnemyMgr.attackerList.length; ++i)
        {
            Enemy@ e = gEnemyMgr.attackerList[i];
            if (!e.CanBeCountered())
                continue;
            Vector3 posDiff = e.sceneNode.worldPosition - myPos;
            posDiff.y = 0;
            float distSQR = posDiff.lengthSquared;
            if (distSQR > maxCounterDistSQR)
                continue;
            if (curDistSQR > distSQR)
            {
                counterEnemy = e;
                curDistSQR = distSQR;
                curPosDiff = posDiff;
            }
        }

        if (counterEnemy is null)
            return;

        Print("Choose Couter Enemy " + counterEnemy.sceneNode.name);
        PlayerCounterState@ state = cast<PlayerCounterState@>(stateMachine.FindState("CounterState"));
        if (state is null)
            return;
        @state.counterEnemy = counterEnemy;
        stateMachine.ChangeState("CounterState");
    }

    void Hit()
    {

    }


    String GetDebugText()
    {
        return Character::GetDebugText() +  "player combo=" + String(combo) + "\n";
    }

    void CommonStateFinishedOnGroud()
    {
        if (gInput.IsLeftStickInDeadZone() && gInput.HasLeftStickBeenStationary(0.1))
            stateMachine.ChangeState("StandState");
        else {
            stateMachine.ChangeState("MoveState");
        }
    }
};


// computes the difference between the characters current heading and the
// heading the user wants them to go in.
float ComputeDifference_Player(Node@ n)
{
    // if the user is not pushing the stick anywhere return.  this prevents the character from turning while stopping (which
    // looks bad - like the skid to stop animation)
    if( gInput.m_leftStickMagnitude < 0.5f )
        return 0;

    Vector3 camDir = cameraNode.worldRotation * Vector3(0, 0, 1);
    float cameraAngle = Atan2(camDir.x, camDir.z);
    // check the difference between the characters current heading and the desired heading from the gamepad
    return ComputeDifference(n, gInput.m_leftStickAngle + cameraAngle);
}

//  divides a circle into numSlices and returns the index (in clockwise order) of the slice which
//  contains the gamepad's angle relative to the camera.
int RadialSelectAnimation_Player(Node@ n, int numDirections)
{
    Vector3 camDir = cameraNode.worldRotation * Vector3(0, 0, 1);
    float cameraAngle = Atan2(camDir.x, camDir.z);
    return RadialSelectAnimation(n, numDirections, gInput.m_leftStickAngle + cameraAngle);
}