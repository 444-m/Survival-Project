return {
    emit = function(container: Instance | ParticleEmitter, search: "child" | "desc")
        if not container then return end

        local function emitParticle(emitter: ParticleEmitter)
            pcall(function()
                task.delay(
                    (emitter:GetAttribute("EmitDelay") or 0) :: number,
                    emitter.Emit,
                    emitter,
                    (emitter:GetAttribute("EmitCount") or 0) :: number
                )
            end)
        end

        if container:IsA("ParticleEmitter") then
            emitParticle(container :: ParticleEmitter)
            return
        end

        local children = search == "desc" and container:GetDescendants() or container:GetChildren()

        for _, particle in next, children do
			if particle:IsA("ParticleEmitter") then
				task.wait()
                emitParticle(particle :: ParticleEmitter)
            end
        end
    end;

    enable = function(container: Instance | ParticleEmitter, search: "child" | "desc")
        if not container then return end

        local function setEnabled(instance: Instance, enabled: boolean)
            if instance:IsA("ParticleEmitter") then
                (instance :: ParticleEmitter).Enabled = enabled
            elseif instance:IsA("Trail") then
                (instance :: Trail).Enabled = enabled
            elseif instance:IsA("Beam") then
                (instance :: Beam).Enabled = enabled
            elseif instance:IsA("Smoke") then
                (instance :: Smoke).Enabled = enabled
            elseif instance:IsA("Fire") then
                (instance :: Fire).Enabled = enabled
            elseif instance:IsA("Sparkles") then
                (instance :: Sparkles).Enabled = enabled
            end
        end

        if container:IsA("ParticleEmitter")
            or container:IsA("Trail")
            or container:IsA("Beam")
            or container:IsA("Smoke")
            or container:IsA("Fire")
            or container:IsA("Sparkles")
        then
            setEnabled(container, true)
            return
        end

        local children = search == "desc" and container:GetDescendants() or container:GetChildren()

        for _, particle in next, children do
			if particle:IsA("ParticleEmitter")
                or particle:IsA("Trail")
                or particle:IsA("Beam")
                or particle:IsA("Smoke")
                or particle:IsA("Fire")
                or particle:IsA("Sparkles")
            then
				task.wait();
                setEnabled(particle, true)
            end
        end
    end;

    disable = function(container: Instance | ParticleEmitter, search: "child" | "desc")
        if not container then return end

        local function setEnabled(instance: Instance, enabled: boolean)
            if instance:IsA("ParticleEmitter") then
                (instance :: ParticleEmitter).Enabled = enabled
            elseif instance:IsA("Trail") then
                (instance :: Trail).Enabled = enabled
            elseif instance:IsA("Beam") then
                (instance :: Beam).Enabled = enabled
            elseif instance:IsA("Smoke") then
                (instance :: Smoke).Enabled = enabled
            elseif instance:IsA("Fire") then
                (instance :: Fire).Enabled = enabled
            elseif instance:IsA("Sparkles") then
                (instance :: Sparkles).Enabled = enabled
            end
        end

        if container:IsA("ParticleEmitter")
            or container:IsA("Trail")
            or container:IsA("Beam")
            or container:IsA("Smoke")
            or container:IsA("Fire")
            or container:IsA("Sparkles")
        then
            setEnabled(container, false)
            return
        end

        local children = search == "desc" and container:GetDescendants() or container:GetChildren()

        for _, particle in next, children do
			if particle:IsA("ParticleEmitter")
                or particle:IsA("Trail")
                or particle:IsA("Beam")
                or particle:IsA("Smoke")
                or particle:IsA("Fire")
                or particle:IsA("Sparkles")
            then
				task.wait();
                setEnabled(particle, false)
            end
        end
    end;
}
