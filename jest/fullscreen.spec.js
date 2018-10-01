require("../app/assets/javascripts/fullscreen.js")

let _window = {innerWidth: 600, innerHeight:400}
let _screen = {width: 1200, height: 800 }
let transform = {}
// Hidden constant MAX_WIDTH in fullscreen.js is 2000
const maxWidth = 2000;

describe("GetIframeTransforms", () => {

  it("should exist", () => {
    expect(global.GetIframeTransforms).toBeDefined()
  })

  describe("Normal sized screens", () => {
    beforeEach(()=> {
      transform = global.GetIframeTransforms(_window, _screen)
    });
    it('transforms', ()=> {
      expect(transform.unscaledWidth).toBe(1200)
      expect(transform.scale).toBe(_window.innerWidth / _screen.width)
      expect(transform.unscaledHeight).toBe(_window.innerHeight / transform.scale)
      expect(transform.scale).toBeCloseTo(0.5, 1)
      expect(transform.unscaledHeight).toBeCloseTo(800, 1)
    })
  })

  describe("Very wide screens" , () => {
    beforeEach(()=> {
      // MAX_WIDTH is defined as 2000
      _screen.width=3000;
      transform = global.GetIframeTransforms(_window, _screen)
    });

    it('transforms', ()=> {
      expect(transform.unscaledWidth).toBe(maxWidth)
      expect(transform.scale).toBe(_window.innerWidth / maxWidth)
      expect(transform.unscaledHeight).toBe(_window.innerHeight / transform.scale)
      expect(transform.scale).toBeCloseTo(0.3, 1)
      expect(transform.unscaledHeight).toBeCloseTo(1333.3, 1)
    })
  })

  describe("Tall windows", () => {
    beforeEach(()=> {
      _screen.width=1200;
      _window.innerWidth = 400;
      _window.innerHeight = 900;
      transform = global.GetIframeTransforms(_window, _screen)
    });
    it('transforms', ()=> {
      expect(transform.unscaledWidth).toBe(1200)
      expect(transform.scale).toBe(_window.innerWidth / _screen.width)
      expect(transform.unscaledHeight).toBe(_window.innerHeight / transform.scale)
      expect(transform.scale).toBeCloseTo(0.3, 1)
      expect(transform.unscaledHeight).toBeCloseTo(2700, 1)
    })
  })
})

