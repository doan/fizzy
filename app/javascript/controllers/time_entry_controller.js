import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    url: String
  }
  
  static targets = [ "formContainer" ]

  async showPrompt(event) {
    event.preventDefault()
    event.stopPropagation()

    try {
      const cardContainer = this.element.closest('.card-perma')
      const container = cardContainer?.querySelector('[id*="time_entry_container"]')
      const existingForm = container?.querySelector('[id*="time_entry_form"]')
      
      if (existingForm && container.innerHTML.trim() !== '') {
        // Hide form if it's already visible by clearing the container
        container.innerHTML = ''
      } else {
        // Fetch and show the form
        const response = await get(this.urlValue, { responseKind: "turbo-stream" })
        
        if (response.ok) {
          const html = await response.responseText
          if (html) {
            Turbo.renderStreamMessage(html)
            
            // Focus the input after form is added
            setTimeout(() => {
              const form = container?.querySelector('[id*="time_entry_form"]')
              const input = form?.querySelector('input[type="number"]')
              input?.focus()
            }, 100)
          }
        }
      }
    } catch (error) {
      console.error("Error showing time entry form:", error)
    }
  }

  hideForm() {
    const cardContainer = this.element.closest('.card-perma')
    const form = cardContainer?.querySelector('[id^="time-entry-form"], [id*="time_entry_form"]')
    if (form) {
      form.hidden = true
    }
  }
}
