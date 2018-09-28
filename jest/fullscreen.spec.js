require("../app/assets/javascripts/fullscreen.js")

let _window = {innerWidth: 600, innerHeight:400}
let _screen = {width: 1200, height: 800 }
let transform = {}
const maxWidth = 2000; // Hidden constant in fullscreen.js

describe("GetIframeTransforms", () => {

  it("should exist", () => {
    expect(global.GetIframeTransforms).toBeDefined()
  })

  describe("Normal sized screens", () => {
    beforeEach(()=> {
      transform = global.GetIframeTransforms(_window, _screen)
    });
    it('transforms', ()=> {
      expect(transform.width).toBe(1200)
      expect(transform.scale).toBe(_window.innerWidth / _screen.width)
      expect(transform.height).toBe(_window.innerHeight / transform.scale)
    })
  })

  describe("Very wide screens" , () => {
    beforeEach(()=> {
      _screen.width=3000; //MAX_WIDTH is defined as 2000
      transform = global.GetIframeTransforms(_window, _screen)
    });

    it('transforms', ()=> {
      expect(transform.width).toBe(maxWidth)
      expect(transform.scale).toBe(_window.innerWidth /maxWidth)
      expect(transform.height).toBe(_window.innerHeight / transform.scale)
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
      expect(transform.width).toBe(1200)
      expect(transform.scale).toBe(_window.innerWidth / _screen.width)
      expect(transform.height).toBe(_window.innerHeight / transform.scale)
    })
  })
})

