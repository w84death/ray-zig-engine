const splatFiles = [
    "sharp/ml-sharp_japan.splat",
    "sharp/ml-sharp_bridge.splat",
    "sharp/ml-sharp_arch.splat",
    "sharp/ml-sharp_nfs.splat",
    "sharp/ml-sharp_wartostrada.splat",
    "sharp/ml-sharp_kwiatki.splat",
    "sharp/ml-sharp_tree.splat",
    "sharp/photo4.splat",
    "sharp/photo5.splat",
    "sharp/photo6.splat",
    "sharp/photo7.splat",
    "sharp/photo8.splat",
    "sharp/photo9.splat",
    "sharp/room1.splat",
    "sharp/room2.splat",
    "sharp/palace.splat",
    "sharp/tropics1.splat",
    "sharp/tropics2.splat",
    "sharp/fishes1.splat",
    "sharp/fishes2.splat",
    "sharp/fishes3.splat",
    "sharp/fishes4.splat",
    "sharp/fishes6.splat",
    "sharp/krzyzacy.splat",
    "sharp/kkj.splat",
];

window.splatFiles = splatFiles;

// --- Math Helpers (Main Thread) ---

function multiply4(a, b) {
    var out = new Float32Array(16);
    // C = A * B (Column-Major)
    for (let i = 0; i < 4; i++) {
        for (let j = 0; j < 4; j++) {
            let sum = 0;
            for (let k = 0; k < 4; k++) {
                sum += a[k * 4 + j] * b[i * 4 + k];
            }
            out[i * 4 + j] = sum;
        }
    }
    return out;
}

function cross(a, b) {
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ];
}

function normalize(a) {
    const len = Math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    if (len === 0) return [0, 0, 0];
    return [a[0] / len, a[1] / len, a[2] / len];
}

function subtract(a, b) {
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
}

function lookAt(eye, target, up) {
    const z = normalize(subtract(eye, target));
    const x = normalize(cross(up, z));
    const y = cross(z, x);

    return [
        x[0],
        y[0],
        z[0],
        0,
        x[1],
        y[1],
        z[1],
        0,
        x[2],
        y[2],
        z[2],
        0,
        -(x[0] * eye[0] + x[1] * eye[1] + x[2] * eye[2]),
        -(y[0] * eye[0] + y[1] * eye[1] + y[2] * eye[2]),
        -(z[0] * eye[0] + z[1] * eye[1] + z[2] * eye[2]),
        1,
    ];
}

// --- Worker ---

function createWorker(self) {
    let buffer;
    let vertexCount = 0;
    let viewProj;
    const rowLength = 3 * 4 + 3 * 4 + 4 + 4;
    let lastProj = [];
    let depthIndex = new Uint32Array();
    let lastVertexCount = 0;

    var _floatView = new Float32Array(1);
    var _int32View = new Int32Array(_floatView.buffer);

    function floatToHalf(float) {
        _floatView[0] = float;
        var f = _int32View[0];
        var sign = (f >> 31) & 0x0001;
        var exp = (f >> 23) & 0x00ff;
        var frac = f & 0x007fffff;
        var newExp;
        if (exp == 0) {
            newExp = 0;
        } else if (exp < 113) {
            newExp = 0;
            frac |= 0x00800000;
            frac = frac >> (113 - exp);
            if (frac & 0x01000000) {
                newExp = 1;
                frac = 0;
            }
        } else if (exp < 142) {
            newExp = exp - 112;
        } else {
            newExp = 31;
            frac = 0;
        }
        return (sign << 15) | (newExp << 10) | (frac >> 13);
    }

    function packHalf2x16(x, y) {
        return (floatToHalf(x) | (floatToHalf(y) << 16)) >>> 0;
    }

    function generateTexture() {
        if (!buffer) return;
        const f_buffer = new Float32Array(buffer);
        const u_buffer = new Uint8Array(buffer);

        var texwidth = 1024 * 2;
        var texheight = Math.ceil((2 * vertexCount) / texwidth);
        var texdata = new Uint32Array(texwidth * texheight * 4);
        var texdata_c = new Uint8Array(texdata.buffer);
        var texdata_f = new Float32Array(texdata.buffer);

        for (let i = 0; i < vertexCount; i++) {
            texdata_f[8 * i + 0] = f_buffer[8 * i + 0];
            texdata_f[8 * i + 1] = f_buffer[8 * i + 1];
            texdata_f[8 * i + 2] = f_buffer[8 * i + 2];

            texdata_c[4 * (8 * i + 7) + 0] = u_buffer[32 * i + 24 + 0];
            texdata_c[4 * (8 * i + 7) + 1] = u_buffer[32 * i + 24 + 1];
            texdata_c[4 * (8 * i + 7) + 2] = u_buffer[32 * i + 24 + 2];
            texdata_c[4 * (8 * i + 7) + 3] = u_buffer[32 * i + 24 + 3];

            let scale = [
                f_buffer[8 * i + 3 + 0],
                f_buffer[8 * i + 3 + 1],
                f_buffer[8 * i + 3 + 2],
            ];
            let rot = [
                (u_buffer[32 * i + 28 + 0] - 128) / 128,
                (u_buffer[32 * i + 28 + 1] - 128) / 128,
                (u_buffer[32 * i + 28 + 2] - 128) / 128,
                (u_buffer[32 * i + 28 + 3] - 128) / 128,
            ];

            const M = [
                1.0 - 2.0 * (rot[2] * rot[2] + rot[3] * rot[3]),
                2.0 * (rot[1] * rot[2] + rot[0] * rot[3]),
                2.0 * (rot[1] * rot[3] - rot[0] * rot[2]),
                2.0 * (rot[1] * rot[2] - rot[0] * rot[3]),
                1.0 - 2.0 * (rot[1] * rot[1] + rot[3] * rot[3]),
                2.0 * (rot[2] * rot[3] + rot[0] * rot[1]),
                2.0 * (rot[1] * rot[3] + rot[0] * rot[2]),
                2.0 * (rot[2] * rot[3] - rot[0] * rot[1]),
                1.0 - 2.0 * (rot[1] * rot[1] + rot[2] * rot[2]),
            ].map((k, i) => k * scale[Math.floor(i / 3)]);

            const sigma = [
                M[0] * M[0] + M[3] * M[3] + M[6] * M[6],
                M[0] * M[1] + M[3] * M[4] + M[6] * M[7],
                M[0] * M[2] + M[3] * M[5] + M[6] * M[8],
                M[1] * M[1] + M[4] * M[4] + M[7] * M[7],
                M[1] * M[2] + M[4] * M[5] + M[7] * M[8],
                M[2] * M[2] + M[5] * M[5] + M[8] * M[8],
            ];
            texdata[8 * i + 4] = packHalf2x16(4 * sigma[0], 4 * sigma[1]);
            texdata[8 * i + 5] = packHalf2x16(4 * sigma[2], 4 * sigma[3]);
            texdata[8 * i + 6] = packHalf2x16(4 * sigma[4], 4 * sigma[5]);
        }

        self.postMessage({ texdata, texwidth, texheight }, [texdata.buffer]);
    }

    function runSort(viewProj) {
        if (!buffer) return;
        const f_buffer = new Float32Array(buffer);
        if (lastVertexCount == vertexCount) {
            let dot =
                lastProj[2] * viewProj[2] +
                lastProj[6] * viewProj[6] +
                lastProj[10] * viewProj[10];
            if (Math.abs(dot - 1) < 0.01) return;
        } else {
            generateTexture();
            lastVertexCount = vertexCount;
        }

        let maxDepth = -Infinity;
        let minDepth = Infinity;
        let sizeList = new Int32Array(vertexCount);
        for (let i = 0; i < vertexCount; i++) {
            let depth =
                ((viewProj[2] * f_buffer[8 * i + 0] +
                    viewProj[6] * f_buffer[8 * i + 1] +
                    viewProj[10] * f_buffer[8 * i + 2]) *
                    -4096) |
                0;
            sizeList[i] = depth;
            if (depth > maxDepth) maxDepth = depth;
            if (depth < minDepth) minDepth = depth;
        }

        let depthInv = (256 * 256 - 1) / (maxDepth - minDepth);
        let counts0 = new Uint32Array(256 * 256);
        for (let i = 0; i < vertexCount; i++) {
            sizeList[i] = ((sizeList[i] - minDepth) * depthInv) | 0;
            counts0[sizeList[i]]++;
        }
        let starts0 = new Uint32Array(256 * 256);
        for (let i = 1; i < 256 * 256; i++)
            starts0[i] = starts0[i - 1] + counts0[i - 1];
        depthIndex = new Uint32Array(vertexCount);
        for (let i = 0; i < vertexCount; i++)
            depthIndex[starts0[sizeList[i]]++] = i;

        lastProj = viewProj;
        self.postMessage({ depthIndex, viewProj, vertexCount }, [
            depthIndex.buffer,
        ]);
    }

    function processPlyBuffer(inputBuffer) {
        const ubuf = new Uint8Array(inputBuffer);
        const header = new TextDecoder().decode(ubuf.slice(0, 1024 * 10));
        const header_end = "end_header\n";
        const header_end_index = header.indexOf(header_end);
        if (header_end_index < 0)
            throw new Error("Unable to read .ply file header");
        const vertexCount = parseInt(/element vertex (\d+)\n/.exec(header)[1]);
        let row_offset = 0,
            offsets = {},
            types = {};
        const TYPE_MAP = {
            double: "getFloat64",
            int: "getInt32",
            uint: "getUint32",
            float: "getFloat32",
            short: "getInt16",
            ushort: "getUint16",
            uchar: "getUint8",
        };
        for (let prop of header
            .slice(0, header_end_index)
            .split("\n")
            .filter((k) => k.startsWith("property "))) {
            const [p, type, name] = prop.split(" ");
            const arrayType = TYPE_MAP[type] || "getInt8";
            types[name] = arrayType;
            offsets[name] = row_offset;
            row_offset += parseInt(arrayType.replace(/[^\d]/g, "")) / 8;
        }

        let dataView = new DataView(
            inputBuffer,
            header_end_index + header_end.length,
        );
        let row = 0;
        const attrs = new Proxy(
            {},
            {
                get(target, prop) {
                    if (!types[prop]) throw new Error(prop + " not found");
                    return dataView[types[prop]](
                        row * row_offset + offsets[prop],
                        true,
                    );
                },
            },
        );

        let sizeList = new Float32Array(vertexCount);
        let sizeIndex = new Uint32Array(vertexCount);
        for (row = 0; row < vertexCount; row++) {
            sizeIndex[row] = row;
            if (!types["scale_0"]) continue;
            const size =
                Math.exp(attrs.scale_0) *
                Math.exp(attrs.scale_1) *
                Math.exp(attrs.scale_2);
            const opacity = 1 / (1 + Math.exp(-attrs.opacity));
            sizeList[row] = size * opacity;
        }

        sizeIndex.sort((b, a) => sizeList[a] - sizeList[b]);

        const rowLength = 3 * 4 + 3 * 4 + 4 + 4;
        const buffer = new ArrayBuffer(rowLength * vertexCount);

        for (let j = 0; j < vertexCount; j++) {
            row = sizeIndex[j];
            const position = new Float32Array(buffer, j * rowLength, 3);
            const scales = new Float32Array(buffer, j * rowLength + 4 * 3, 3);
            const rgba = new Uint8ClampedArray(
                buffer,
                j * rowLength + 4 * 3 + 4 * 3,
                4,
            );
            const rot = new Uint8ClampedArray(
                buffer,
                j * rowLength + 4 * 3 + 4 * 3 + 4,
                4,
            );

            if (types["scale_0"]) {
                const qlen = Math.sqrt(
                    attrs.rot_0 ** 2 +
                        attrs.rot_1 ** 2 +
                        attrs.rot_2 ** 2 +
                        attrs.rot_3 ** 2,
                );
                rot[0] = (attrs.rot_0 / qlen) * 128 + 128;
                rot[1] = (attrs.rot_1 / qlen) * 128 + 128;
                rot[2] = (attrs.rot_2 / qlen) * 128 + 128;
                rot[3] = (attrs.rot_3 / qlen) * 128 + 128;
                scales[0] = Math.exp(attrs.scale_0);
                scales[1] = Math.exp(attrs.scale_1);
                scales[2] = Math.exp(attrs.scale_2);
            } else {
                scales[0] = 0.01;
                scales[1] = 0.01;
                scales[2] = 0.01;
                rot[0] = 255;
                rot[1] = 0;
                rot[2] = 0;
                rot[3] = 0;
            }

            position[0] = attrs.x;
            position[1] = attrs.y;
            position[2] = attrs.z;

            if (types["f_dc_0"]) {
                const SH_C0 = 0.28209479177387814;
                rgba[0] = (0.5 + SH_C0 * attrs.f_dc_0) * 255;
                rgba[1] = (0.5 + SH_C0 * attrs.f_dc_1) * 255;
                rgba[2] = (0.5 + SH_C0 * attrs.f_dc_2) * 255;
            } else {
                rgba[0] = attrs.red;
                rgba[1] = attrs.green;
                rgba[2] = attrs.blue;
            }
            if (types["opacity"]) {
                rgba[3] = (1 / (1 + Math.exp(-attrs.opacity))) * 255;
            } else {
                rgba[3] = 255;
            }
        }
        return buffer;
    }

    function computeCenter(buffer, vertexCount) {
        let sum = [0, 0, 0];
        const dv = new DataView(buffer);
        for (let i = 0; i < vertexCount; i++) {
            let offset = i * rowLength;
            sum[0] += dv.getFloat32(offset, true);
            sum[1] += dv.getFloat32(offset + 4, true);
            sum[2] += dv.getFloat32(offset + 8, true);
        }
        const center = sum.map((s) => s / vertexCount);
        let radius = 0;
        for (let i = 0; i < vertexCount; i++) {
            let offset = i * rowLength;
            let p = [
                dv.getFloat32(offset, true),
                dv.getFloat32(offset + 4, true),
                dv.getFloat32(offset + 8, true),
            ];
            const dist = Math.sqrt(
                Math.pow(p[0] - center[0], 2) +
                    Math.pow(p[1] - center[1], 2) +
                    Math.pow(p[2] - center[2], 2),
            );
            if (dist > radius) radius = dist;
        }
        return { center, radius };
    }

    let sortRunning = false;
    const throttledSort = () => {
        if (!sortRunning) {
            sortRunning = true;
            let lastView = viewProj;
            runSort(lastView);
            setTimeout(() => {
                sortRunning = false;
                if (lastView !== viewProj) {
                    throttledSort();
                }
            }, 0);
        }
    };

    self.onmessage = (e) => {
        if (e.data.ply) {
            vertexCount = 0;
            runSort(viewProj);
            buffer = processPlyBuffer(e.data.ply);
            vertexCount = Math.floor(buffer.byteLength / rowLength);
            postMessage({ buffer: buffer, save: !!e.data.save, vertexCount });
            self.postMessage(computeCenter(buffer, vertexCount));
        } else if (e.data.buffer) {
            buffer = e.data.buffer;
            vertexCount = e.data.vertexCount;
            self.postMessage(computeCenter(buffer, vertexCount));
        } else if (e.data.vertexCount) {
            vertexCount = e.data.vertexCount;
        } else if (e.data.view) {
            viewProj = e.data.view;
            throttledSort();
        }
    };
}

// --- Shaders ---

const vertexShaderSource = `#version 300 es
precision highp float;
precision highp int;

uniform highp usampler2D u_texture;
uniform mat4 projection, view;
uniform vec2 focal;
uniform vec2 viewport;

in vec2 position;
in int index;

out vec4 vColor;
out vec2 vPosition;

void main () {
    uvec4 cen = texelFetch(u_texture, ivec2((uint(index) & 0x3ffu) << 1, uint(index) >> 10), 0);
    vec4 cam = view * vec4(uintBitsToFloat(cen.xyz), 1);
    vec4 pos2d = projection * cam;

    float clip = 5.0 * pos2d.w;
    if (pos2d.z < -clip || pos2d.x < -clip || pos2d.x > clip || pos2d.y < -clip || pos2d.y > clip) {
        gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
        return;
    }

    uvec4 cov = texelFetch(u_texture, ivec2(((uint(index) & 0x3ffu) << 1) | 1u, uint(index) >> 10), 0);
    vec2 u1 = unpackHalf2x16(cov.x), u2 = unpackHalf2x16(cov.y), u3 = unpackHalf2x16(cov.z);
    mat3 Vrk = mat3(u1.x, u1.y, u2.x, u1.y, u2.y, u3.x, u2.x, u3.x, u3.y);

    mat3 J = mat3(
        focal.x / cam.z, 0., -(focal.x * cam.x) / (cam.z * cam.z),
        0., -focal.y / cam.z, (focal.y * cam.y) / (cam.z * cam.z),
        0., 0., 0.
    );

    mat3 T = transpose(mat3(view)) * J;
    mat3 cov2d = transpose(T) * Vrk * T;

    float mid = (cov2d[0][0] + cov2d[1][1]) / 2.0;
    float radius = length(vec2((cov2d[0][0] - cov2d[1][1]) / 2.0, cov2d[0][1]));
    float lambda1 = mid + radius, lambda2 = mid - radius;

    if(lambda2 < 0.0) return;
    vec2 diagonalVector = normalize(vec2(cov2d[0][1], lambda1 - cov2d[0][0]));
    vec2 majorAxis = min(sqrt(2.0 * lambda1), 1024.0) * diagonalVector;
    vec2 minorAxis = min(sqrt(2.0 * lambda2), 1024.0) * vec2(diagonalVector.y, -diagonalVector.x);

    vColor = clamp(pos2d.z/pos2d.w+1.0, 0.0, 1.0) * vec4((cov.w) & 0xffu, (cov.w >> 8) & 0xffu, (cov.w >> 16) & 0xffu, (cov.w >> 24) & 0xffu) / 255.0;
    vPosition = position;

    vec2 vCenter = vec2(pos2d) / pos2d.w;
    gl_Position = vec4(
        vCenter
        + position.x * majorAxis / viewport
        + position.y * minorAxis / viewport, 0.0, 1.0);
}
`;

const fragmentShaderSource = `#version 300 es
precision highp float;

in vec4 vColor;
in vec2 vPosition;

out vec4 fragColor;

void main () {
    float A = -dot(vPosition, vPosition);
    if (A < -4.0) discard;
    float B = exp(A) * vColor.a;
    fragColor = vec4(B * vColor.rgb, B);
}
`;

// --- Main Application ---

async function main() {
    const params = new URLSearchParams(location.search);
    const fileIndex = parseInt(params.get("file")) || 0;
    const selectedFile = splatFiles[fileIndex] || splatFiles[0];

    // UI Elements
    const canvas = document.getElementById("canvas");
    const fpsElement = document.getElementById("fps");
    const camInfo = document.getElementById("camid");

    if (camInfo) camInfo.innerText = "Loading...";

    // Setup WebGL
    const gl = canvas.getContext("webgl2", {
        antialias: false,
        powerPreference: "high-performance",
    });

    if (!gl) throw new Error("WebGL2 not supported");

    // Shaders
    const vertexShader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertexShader, vertexShaderSource);
    gl.compileShader(vertexShader);
    if (!gl.getShaderParameter(vertexShader, gl.COMPILE_STATUS))
        console.error(gl.getShaderInfoLog(vertexShader));

    const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragmentShader, fragmentShaderSource);
    gl.compileShader(fragmentShader);
    if (!gl.getShaderParameter(fragmentShader, gl.COMPILE_STATUS))
        console.error(gl.getShaderInfoLog(fragmentShader));

    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    gl.useProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS))
        console.error(gl.getProgramInfoLog(program));

    // Uniforms
    const u_projection = gl.getUniformLocation(program, "projection");
    const u_viewport = gl.getUniformLocation(program, "viewport");
    const u_focal = gl.getUniformLocation(program, "focal");
    const u_view = gl.getUniformLocation(program, "view");
    const u_texture = gl.getUniformLocation(program, "u_texture");
    gl.uniform1i(u_texture, 0);

    // Buffers
    const triangleVertices = new Float32Array([-2, -2, 2, -2, 2, 2, -2, 2]);
    const vertexBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, triangleVertices, gl.STATIC_DRAW);

    const a_position = gl.getAttribLocation(program, "position");
    gl.enableVertexAttribArray(a_position);
    gl.vertexAttribPointer(a_position, 2, gl.FLOAT, false, 0, 0);

    const indexBuffer = gl.createBuffer();
    const a_index = gl.getAttribLocation(program, "index");
    gl.enableVertexAttribArray(a_index);
    gl.bindBuffer(gl.ARRAY_BUFFER, indexBuffer);
    gl.vertexAttribIPointer(a_index, 1, gl.INT, false, 0, 0);
    gl.vertexAttribDivisor(a_index, 1);

    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.disable(gl.DEPTH_TEST);
    gl.enable(gl.BLEND);
    gl.blendFuncSeparate(
        gl.ONE,
        gl.ONE_MINUS_SRC_ALPHA,
        gl.ONE,
        gl.ONE_MINUS_SRC_ALPHA,
    );
    gl.blendEquationSeparate(gl.FUNC_ADD, gl.FUNC_ADD);

    // Worker setup
    const worker = new Worker(
        URL.createObjectURL(
            new Blob(["(", createWorker.toString(), ")(self)"], {
                type: "application/javascript",
            }),
        ),
    );

    let splatData = null;
    let vertexCount = 0;

    // Camera State (Orbit)
    let camState = {
        distance: 1.0,
        theta: Math.PI,
        phi: 0.0,
        target: [0, 0, 1.5],
        lastX: 0,
        lastY: 0,
        dragging: false,
    };

    let projectionMatrix, viewMatrix;

    // Interaction Handlers
    canvas.addEventListener("mousedown", (e) => {
        camState.dragging = true;
        camState.lastX = e.clientX;
        camState.lastY = e.clientY;
        if (!document.pointerLockElement) canvas.style.cursor = "grabbing";
    });

    window.addEventListener("mouseup", () => {
        camState.dragging = false;
        canvas.style.cursor = "grab";
    });

    window.addEventListener("mousemove", (e) => {
        if (!camState.dragging) return;
        const dx = e.clientX - camState.lastX;
        const dy = e.clientY - camState.lastY;
        camState.lastX = e.clientX;
        camState.lastY = e.clientY;

        camState.theta -= dx * 0.005;
        camState.theta = Math.max(
            Math.PI - Math.PI / 6,
            Math.min(Math.PI + Math.PI / 6, camState.theta),
        );
        camState.phi += dy * 0.005;
        camState.phi = Math.max(
            -Math.PI / 6,
            Math.min(Math.PI / 6, camState.phi),
        );
    });

    canvas.addEventListener(
        "touchstart",
        (e) => {
            e.preventDefault();
            camState.dragging = true;
            camState.lastX = e.touches[0].clientX;
            camState.lastY = e.touches[0].clientY;
        },
        { passive: false },
    );

    canvas.addEventListener(
        "touchend",
        (e) => {
            e.preventDefault();
            camState.dragging = false;
        },
        { passive: false },
    );

    canvas.addEventListener(
        "touchmove",
        (e) => {
            e.preventDefault();
            if (!camState.dragging) return;
            const touch = e.touches[0];
            const dx = touch.clientX - camState.lastX;
            const dy = touch.clientY - camState.lastY;
            camState.lastX = touch.clientX;
            camState.lastY = touch.clientY;

            camState.theta += dx * 0.005;
            camState.theta = Math.max(
                Math.PI - Math.PI / 6,
                Math.min(Math.PI + Math.PI / 6, camState.theta),
            );
            camState.phi -= dy * 0.005;
            camState.phi = Math.max(
                -Math.PI / 6,
                Math.min(Math.PI / 6, camState.phi),
            );
        },
        { passive: false },
    );

    canvas.addEventListener(
        "wheel",
        (e) => {
            e.preventDefault();
            camState.distance *= Math.pow(1.001, e.deltaY * 0.1);

            camState.distance = Math.max(0.8, camState.distance);
            camState.distance = Math.min(7, camState.distance);

            updateProjections();
        },
        { passive: false },
    );

    const k_dolly = 2.0 * Math.tan((60 * Math.PI) / 360);

    const updateProjections = () => {
        const width = canvas.width;
        const height = canvas.height;
        const aspect = width / height;
        const near = 0.1;
        const far = 1000.0;

        const f = camState.distance / k_dolly;
        const rangeInv = 1.0 / (near - far);

        projectionMatrix = [
            f / aspect,
            0,
            0,
            0,
            0,
            f,
            0,
            0,
            0,
            0,
            (near + far) * rangeInv,
            -1,
            0,
            0,
            near * far * rangeInv * 2,
            0,
        ];

        const fy = 0.5 * height * f;
        const fx = 0.5 * width * (f / aspect);

        gl.uniform2fv(u_focal, new Float32Array([fx, fy]));
        gl.uniform2fv(u_viewport, new Float32Array([width, height]));
        gl.uniformMatrix4fv(u_projection, false, projectionMatrix);
    };

    const resize = () => {
        const width = window.innerWidth;
        const height = window.innerHeight;
        canvas.width = width;
        canvas.height = height;
        gl.viewport(0, 0, width, height);
        updateProjections();
    };

    window.addEventListener("resize", resize);
    resize();

    worker.onmessage = (e) => {
        if (e.data.texdata) {
            const { texdata, texwidth, texheight } = e.data;
            gl.bindTexture(gl.TEXTURE_2D, texture);
            gl.texImage2D(
                gl.TEXTURE_2D,
                0,
                gl.RGBA32UI,
                texwidth,
                texheight,
                0,
                gl.RGBA_INTEGER,
                gl.UNSIGNED_INT,
                texdata,
            );
        } else if (e.data.depthIndex) {
            const { depthIndex } = e.data;
            gl.bindBuffer(gl.ARRAY_BUFFER, indexBuffer);
            gl.bufferData(gl.ARRAY_BUFFER, depthIndex, gl.DYNAMIC_DRAW);
            vertexCount = e.data.vertexCount;
        }
    };

    // Load File
    const rowLength = 3 * 4 + 3 * 4 + 4 + 4;
    const url = new URL(selectedFile, window.location.origin + "/");
    const req = await fetch(url, { mode: "cors", credentials: "omit" });
    if (req.status != 200)
        throw new Error(req.status + " Unable to load " + req.url);

    const reader = req.body.getReader();
    const contentLength = parseInt(req.headers.get("content-length"));
    splatData = new Uint8Array(contentLength);

    let bytesRead = 0;
    let lastFrame = 0;
    let avgFps = 0;

    const render = (now) => {
        const cx =
            camState.distance *
            Math.cos(camState.phi) *
            Math.sin(camState.theta);
        const cy = camState.distance * Math.sin(camState.phi);
        const cz =
            camState.distance *
            Math.cos(camState.phi) *
            Math.cos(camState.theta);

        const eye = [
            camState.target[0] + cx,
            camState.target[1] + cy,
            camState.target[2] + cz,
        ];

        viewMatrix = lookAt(eye, camState.target, [0, -1, 0]);

        // Worker needs View * Projection
        const viewProj = multiply4(projectionMatrix, viewMatrix);
        worker.postMessage({ view: viewProj });

        gl.clearColor(0, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT);

        if (vertexCount > 0) {
            gl.uniformMatrix4fv(u_view, false, viewMatrix);
            gl.drawArraysInstanced(gl.TRIANGLE_FAN, 0, 4, vertexCount);
            const spinner = document.getElementById("spinner");
            if (spinner) spinner.style.display = "none";
        }

        const currentFps = 1000 / (now - lastFrame) || 0;
        avgFps = avgFps * 0.9 + currentFps * 0.1;
        if (fpsElement) fpsElement.innerText = Math.round(avgFps) + " fps";
        lastFrame = now;

        requestAnimationFrame(render);
    };

    requestAnimationFrame(render);

    // Stream loading
    const isPly = (data) =>
        data[0] === 112 && data[1] === 108 && data[2] === 121 && data[3] === 10;

    let lastVertexCount = -1;

    while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        splatData.set(value, bytesRead);
        bytesRead += value.length;

        const currentVertexCount = Math.floor(bytesRead / rowLength);

        if (currentVertexCount > lastVertexCount) {
            if (!isPly(splatData)) {
                worker.postMessage({
                    buffer: splatData.buffer,
                    vertexCount: currentVertexCount,
                });
            }
            lastVertexCount = currentVertexCount;
            const progress = document.getElementById("progress");
            if (progress)
                progress.style.width =
                    Math.min(100, (bytesRead / contentLength) * 100) + "%";
        }
    }

    if (isPly(splatData)) {
        worker.postMessage({ ply: splatData.buffer, save: false });
    } else {
        worker.postMessage({
            buffer: splatData.buffer,
            vertexCount: Math.floor(bytesRead / rowLength),
        });
        const progress = document.getElementById("progress");
        if (progress) progress.style.display = "none";
    }
}

function initFileSelector() {
    const select = document.getElementById("splat-select");
    const welcomeSelect = document.getElementById("welcome-splat-select");

    function populateSelect(selectElement, placeholder) {
        if (selectElement) {
            selectElement.innerHTML = "";
            if (placeholder) {
                const option = document.createElement("option");
                option.value = "";
                option.textContent = placeholder;
                option.disabled = true;
                option.selected = true;
                selectElement.appendChild(option);
            }
            splatFiles.forEach((filename, index) => {
                const option = document.createElement("option");
                option.value = index;
                option.textContent = filename
                    .replace("splat/", "")
                    .replace(".splat", "");
                selectElement.appendChild(option);
            });
        }
    }

    populateSelect(select);
    populateSelect(welcomeSelect, "select image");

    if (select) {
        const params = new URLSearchParams(window.location.search);
        const currentFile = params.get("file") || "0";
        select.value = currentFile;

        select.addEventListener("change", function () {
            const fileIndex = this.value;
            const url = new URL(window.location);
            url.searchParams.set("file", fileIndex);
            window.location = url.toString();
        });
    }

    const welcomeScreen = document.getElementById("welcome-screen");
    const loadButton = document.getElementById("load-splat-button");

    const params = new URLSearchParams(window.location.search);
    const shouldShowWelcome = !params.has("file");

    if (shouldShowWelcome) {
        const fpsElement = document.getElementById("quality");
        const spinner = document.getElementById("spinner");
        if (fpsElement) fpsElement.style.display = "none";
        if (spinner) spinner.style.display = "none";

        if (welcomeScreen) {
            welcomeScreen.classList.remove("hidden");
        }

        if (loadButton && welcomeSelect) {
            loadButton.addEventListener("click", function () {
                const selectedIndex = welcomeSelect.value;
                if (selectedIndex === "") return;
                const url = new URL(window.location);
                url.searchParams.set("file", selectedIndex);
                window.location = url.toString();
            });
        }
    } else {
        if (welcomeScreen) {
            welcomeScreen.classList.add("hidden");
        }
        main().catch((err) => {
            console.error(err);
            document.body.innerHTML = `<div style="color:red; padding: 20px;">Error: ${err.message}</div>`;
        });
    }
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initFileSelector);
} else {
    initFileSelector();
}
