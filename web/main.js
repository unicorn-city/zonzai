let instance;
let canvas;
let canvasContext;
let canvasImageData;

const debug_print = (location, size) => {
  var buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  var decoder = new TextDecoder();
  var string = decoder.decode(buffer);
  console.log(string);
}

let frameTime = performance.now()

const fpsElement = document.getElementById('fps')

const setCanvasDimensions = () => {
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight
  instance.exports.set_window_dimensions(canvas.width, canvas.height);
  canvasImageData = canvasContext.createImageData(
    canvas.width,
    canvas.height
  )
}

window.addEventListener('resize', setCanvasDimensions)

WebAssembly.instantiateStreaming(fetch("./bin/zonzai.wasm"), {
  env: {
    debug_print: debug_print,
  }
}).then(res => {
  instance = res.instance;

  canvas = document.querySelector("canvas");
  canvasContext = canvas.getContext("2d");
  setCanvasDimensions()

  instance.exports.set_rand_seed(BigInt(new Date().getTime()));

  const draw = () => {
    instance.exports.grow_tree();

    const outputPointer = instance.exports.get_output_buffer_pointer();

    const imageDataArray = new Uint8Array(instance.exports.memory.buffer).slice(
      outputPointer,
      outputPointer + canvas.width * canvas.height * 4
    );

    if (imageDataArray.length <= canvasImageData.data.length)
      canvasImageData.data.set(imageDataArray);

    canvasContext.clearRect(0, 0, canvas.width, canvas.height);
    canvasContext.putImageData(canvasImageData, 0, 0);

    let newFrameTime = performance.now()
    if (fpsElement)
      fpsElement.innerText = `${(1000 / ((newFrameTime - frameTime))).toFixed(1)} fps`
    frameTime = newFrameTime

    // window.requestAnimationFrame(draw)
  };

  setInterval(() => {
    draw()
  }, 1);

  draw();
});