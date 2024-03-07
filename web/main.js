let instance
let canvas
let canvasContext
let canvasImageData

let dragging
let mousedown

const CELL_SIZE = 5

const EXAMPLE_PATTERNS = [
  {
    name: "Cell",
    rle: "o!",
  },
  {
    name: "Glider",
    rle: "bob$2bo$3o!",
  },
  {
    name: "Spider",
    rle: "9bo7bo9b$3b2obobob2o3b2obobob2o3b$3obob3o9b3obob3o$o3bobo5bobo5bobo3bo$4b2o6bobo6b2o4b$b2o9bobo9b2ob$b2ob2o15b2ob2ob$5bo15bo!",
  },
  {
    name: "70P23 Oscillator",
    rle: "24bo$12bo9b3o$o11b3o6bo$3o5b2o5bo5b2o$3bo4b2o4b2o$2b2o$19bobo$19bobo$3b2o14b3o3b2o$3b2o3b3o14b2o$8bobo$8bobo$26b2o$14b2o4b2o4bo$7b2o5bo5b2o5b3o$8bo6b3o11bo$5b3o9bo$5bo!",
  },
  {
    name: "P24 Gliderless LWSS Gun",
    rle: "24b2o3b2o$2b2obo2bo15bobobo2bo$o2bob4o17bob4o$2o24bo2bo2b2o$4bob2obo9b2o3bobo3b2o2bo$2ob4ob2o9bo3b3o7b2o$o3bo12bobobob2o$b4o11bobo2bob2o$5b2o3b2o4bobob3o$3b4o3bobob2obobo$2bo3bo5bobo2bo12bo2bobo$bobo8bo3b2o10b2obob3o$bo2b2o3b3o8b2o7bo6bo$2b2obo4b2o8b2o6b2o5bo$5b3o4b3o5bo$6b2ob2o3b2o5bo7bo5b2o$b2ob2obob2o3b2o6b2o4bo6bo$obobo9b2o6b3o4b3obob2o$bo3b6o3bo14bobo2bo$7bo3bo9b2o$10bo10bo$10bo3bo6bo$6bo8bo$7b2o2bo3bo6bo2bo8bo2bo$5b2o9b2o8bo11bo$7bo5bo4bo3bo3bo7bo3bo$12bobo3bo4b4o8b4o$13bo4bo$7b2o3bo3b2o$6bobo3bo2bo$6bo4bo3bo$5b2o5bo2$8b2o8b2o$8bo2b6o2bo$9b2o6b2o$6b3o10b3o$6bo2bobo4bobo2bo$7b2o4b2o4b2o!",
  },
]

const debug_print = (location, size) => {
  var buffer = new Uint8Array(instance.exports.memory.buffer, location, size)
  var decoder = new TextDecoder()
  var string = decoder.decode(buffer)
  console.log(string)
}

let frameTime = performance.now()
let lastFpsUpdateMS = new Date().getTime()
let prevFrameIntervals = []

const patternPaletteElement = document.getElementById("pattern-palette")
const fpsElement = document.getElementById("fps")
const pauseBtnElement = document.getElementById("pause-btn")
const clearBtnElement = document.getElementById("clear-btn")

pauseBtnElement.addEventListener("click", () => {
  const pauseResult = instance.exports.pause()
  pauseBtnElement.innerText = pauseResult ? "unpause" : "pause"
})

clearBtnElement.addEventListener("click", () => {
  instance.exports.clear()
})

const setCanvasDimensions = () => {
  canvas.width = Math.floor((window.innerWidth * 0.96) / CELL_SIZE) * CELL_SIZE
  canvas.height = Math.floor((window.innerHeight - 240) / CELL_SIZE) * CELL_SIZE
  instance.exports.set_window_dimensions(canvas.width, canvas.height)
  canvasImageData = canvasContext.createImageData(canvas.width, canvas.height)
}

window.addEventListener("resize", setCanvasDimensions)

EXAMPLE_PATTERNS.forEach((p, i) => {
  const patternButtonElement = document.createElement("button")
  if (i == 0) {
    patternButtonElement.style.outline = "2px solid white"
  }
  patternButtonElement.classList.add("btn")
  patternButtonElement.innerText = p.name
  patternButtonElement.addEventListener("click", () => {
    // TODO: There's definitely a better way to do this w/o allocating
    // cause I just copy it into the same wasm fixed buffer
    const rleBuffer = Uint8Array.from(
      Array.from(p.rle).map((letter) => letter.charCodeAt(0)),
    )

    var ptr = instance.exports.alloc(rleBuffer.length)
    var mem = new Uint8Array(
      instance.exports.memory.buffer,
      ptr,
      rleBuffer.length,
    )
    mem.set(new Uint8Array(rleBuffer))

    instance.exports.select_pattern(ptr)

    for (const button of patternPaletteElement.children) {
      button.style.outline = "none"
    }
    patternButtonElement.style.outline = "2px solid white"
  })

  patternPaletteElement.appendChild(patternButtonElement)
})

WebAssembly.instantiateStreaming(fetch("./bin/zonzai.wasm"), {
  env: {
    debug_print: debug_print,
  },
}).then((res) => {
  instance = res.instance

  canvas = document.querySelector("canvas")
  canvasContext = canvas.getContext("2d")
  setCanvasDimensions()

  let mousePosition = { x: 0, y: 0 }

  canvas.addEventListener("mouseup", (e) => {
    mousedown = false
    dragging = false
    instance.exports.set_dragging(false)
  })

  canvas.addEventListener("mousedown", (e) => {
    mousedown = true
  })

  canvas.addEventListener("click", (e) => {
    instance.exports.click()
  })

  canvas.addEventListener("mousemove", (e) => {
    if (dragging) {
      instance.exports.set_dragging(true)
    }

    let canvasBoundingRect = canvas.getBoundingClientRect()
    const newMousePosition = {
      x: e.x - canvasBoundingRect.left,
      y: canvas.height + canvasBoundingRect.top - e.y,
    }
    if (
      mousePosition.x !== newMousePosition.x ||
      mousePosition.y !== newMousePosition.y
    ) {
      if (mousedown) {
        dragging = true
      } else {
        dragging = false
      }
      instance.exports.move_mouse(newMousePosition.x, newMousePosition.y)
      mousePosition = newMousePosition
    }
  })

  instance.exports.setup()

  const draw = () => {
    instance.exports.draw()

    const outputPointer = instance.exports.get_output_buffer_pointer()

    const imageDataArray = new Uint8Array(instance.exports.memory.buffer).slice(
      outputPointer,
      outputPointer + canvas.width * canvas.height * 4,
    )

    if (imageDataArray.length <= canvasImageData.data.length)
      canvasImageData.data.set(imageDataArray)

    canvasContext.putImageData(canvasImageData, 0, 0)

    let newFrameTime = performance.now()
    prevFrameIntervals.push(newFrameTime - frameTime)
    if (prevFrameIntervals.length > 10) prevFrameIntervals.shift()
    frameTime = newFrameTime

    window.requestAnimationFrame(draw)
  }

  setInterval(() => {
    if (fpsElement) {
      fpsElement.innerText = `${Math.round(1000 / (prevFrameIntervals.reduce((acc, curr) => (acc += curr), 0) / prevFrameIntervals.length))} fps`
    }
  }, 150)

  draw()
})
