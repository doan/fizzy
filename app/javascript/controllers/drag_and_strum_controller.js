import { Controller } from "@hotwired/stimulus"

const MANDOLIN_NOTES = [
  "/audio/mandolin/B3.mp3",
  "/audio/mandolin/C3.mp3",
  "/audio/mandolin/D4.mp3",
  "/audio/mandolin/E3.mp3",
  "/audio/mandolin/Fsharp4.mp3",
  "/audio/mandolin/G3.mp3"
]

export default class extends Controller {
  static targets = [ "container" ]

  connect() {
    this.preloadedAudioFiles = MANDOLIN_NOTES.map(file => {
      const audio = new Audio(file)
      audio.load()
      return audio
    });
  }

  dragEnter(event) {
    event.preventDefault()
    const container = this.#containerContaining(event.target)

    if (!container) { return }

    if (container !== this.sourceContainer && event.shiftKey) {
      this.#playSound()
    }
  }

  #containerContaining(element) {
    return this.containerTargets.find(container => container.contains(element) || container === element)
  }

  #playSound() {
    const randomIndex = Math.floor(Math.random() * this.preloadedAudioFiles.length)
    const audio = this.preloadedAudioFiles[randomIndex]
    const audioInstance = new Audio(audio.src)
    audioInstance.play()
  }
}
