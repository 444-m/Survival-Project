local helper = {}

function helper.recursiveSearch(t: {}, k: any)
    for i in next, t do
        if k == i then return t[i] end 
        if type(t[i]) == "table" then
            local found = helper.recursiveSearch(t[i], k)
            if found then return found end
        end
    end; return nil
end

return helper