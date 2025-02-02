class Context
  attr_reader :form, :support_details

  def initialize(form:, store:)
    @form = form
    @form_context = FormContext.new(store)
    @step_factory = StepFactory.new(form:)
    @journey = Journey.new(form_context: @form_context, step_factory: @step_factory)

    @support_details = OpenStruct.new({
      email: form.support_email,
      phone: form.support_phone,
      url: form.support_url,
      url_text: form.support_url_text,
    })
  end

  def find_or_create(page_slug)
    step = completed_steps.find { |s| s.page_slug == page_slug }
    step || @step_factory.create_step(page_slug)
  end

  def save_step(step)
    return false unless step.valid?

    step.save_to_context(@form_context)
  end

  def previous_step(page_slug)
    index = completed_steps.find_index { |step| step.page_slug == page_slug }
    return nil if completed_steps.empty? || index&.zero?

    return completed_steps.last.page_id if index.nil?

    completed_steps[index - 1].page_id
  end

  def next_page_slug
    return nil if completed_steps.last&.end_page?

    completed_steps.last&.next_page_slug_after_routing || @step_factory.start_step.page_slug
  end

  def can_visit?(page_slug)
    (completed_steps.map(&:page_slug).include? page_slug) || page_slug == next_page_slug
  end

  def completed_steps
    @journey.completed_steps
  end

  def clear
    @form_context.clear(form.id)
  end

  def form_submitted?
    @form_context.form_submitted?(form.id)
  end
end
