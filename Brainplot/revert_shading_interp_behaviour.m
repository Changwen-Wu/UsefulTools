function ncd = revert_shading_interp_behaviour(s, m)
% shading interp behaviour is different across matlab versions
% we revert the shading interp behaviour to be like r2014a

s = get(s);
cdat = s.FaceVertexCData;
cl = get(gca, 'CLim');
sz = cl(2) - cl(1);
idxf = zeros(length(cdat), 1);
ncd = zeros(length(cdat), 1, 3);

for x = 1: length(cdat)
    for y = 1
        c = cdat(x, y);
        idxf(x, y) = ((c - cl(1)) / sz) * (size(m, 1) - 1);
        ncd(x, y, 1: 3) = m(round(idxf(x, y)) + 1, :);
    end
end
end