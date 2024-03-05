let instance
let canvas
let canvasContext
let canvasImageData

const debug_print = (location, size) => {
  var buffer = new Uint8Array(instance.exports.memory.buffer, location, size)
  var decoder = new TextDecoder()
  var string = decoder.decode(buffer)
  console.log(string)
}

let frameTime = performance.now()
let lastFpsUpdateMS = new Date().getTime()
let prevFrameIntervals = []

const fpsElement = document.getElementById("fps")
const pauseBtnElement = document.getElementById("pauseBtn")

pauseBtnElement.addEventListener("click", () => {
  instance.exports.pause()
})

const setCanvasDimensions = () => {
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight
  instance.exports.set_window_dimensions(canvas.width, canvas.height)
  canvasImageData = canvasContext.createImageData(canvas.width, canvas.height)
}

window.addEventListener("resize", setCanvasDimensions)

const memory = new WebAssembly.Memory({
  initial: 1000,
  maximum: 65536,
})

WebAssembly.instantiateStreaming(fetch("./bin/zonzai.wasm"), {
  js: { mem: memory },
  env: {
    debug_print: debug_print,
  },
}).then((res) => {
  instance = res.instance

  canvas = document.querySelector("canvas")
  canvasContext = canvas.getContext("2d")
  setCanvasDimensions()

  let mousedown = false

  canvas.addEventListener("mousedown", (e) => {
    mousedown = true
    instance.exports.mouse_click(e.x, canvas.height - e.y)
  })
  canvas.addEventListener("mouseup", (e) => {
    mousedown = false
  })
  canvas.addEventListener("mousemove", (e) => {
    if (mousedown) {
      instance.exports.mouse_click(e.x, canvas.height - e.y)
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
