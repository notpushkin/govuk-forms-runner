module Forms
  class PageController < BaseController
    before_action :prepare_step, :changing_existing_answer, :check_goto_page_before_routing_page

    def show
      redirect_to form_page_path(@step.form_id, @step.form_slug, current_context.next_page_slug) unless current_context.can_visit?(@step.page_slug)
      back_link(@step.page_slug)
      setup_instance_vars_for_view
    end

    def save
      page_params = params.require(:question).permit(*@step.params)
      @step.update!(page_params)

      if current_context.save_step(@step)
        unless mode.preview?
          LogEventService.new(current_context, @step, request, changing_existing_answer, page_params).log_page_save
        end
        redirect_to next_page
      else
        setup_instance_vars_for_view
        render :show
      end
    end

  private

    def prepare_step
      page_slug = params.require(:page_slug)
      @step = current_context.find_or_create(page_slug)

      @support_details = current_context.support_details
    end

    def setup_instance_vars_for_view
      @is_question = true
      @question_edit_link = "#{Settings.forms_admin.base_url}/forms/#{@step.form_id}/pages/#{@step.page_slug}/edit"
    end

    def changing_existing_answer
      @changing_existing_answer = ActiveModel::Type::Boolean.new.cast(params[:changing_existing_answer])
    end

    def back_link(page_slug)
      previous_step = current_context.previous_step(page_slug)
      if @changing_existing_answer
        @back_link = check_your_answers_path(form_id: current_context.form.id)
      elsif previous_step
        @back_link = form_page_path(@step.form_id, @step.form_slug, previous_step)
      end
    end

    def next_page
      if @changing_existing_answer
        check_your_answers_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug)
      elsif @step.routing_conditions.any?
        calculate_page_routing
      else
        form_page_path(@step.form_id, @step.form_slug, @step.next_page_slug)
      end
    end

    def calculate_page_routing
      if @step.question.show_answer == @step.routing_conditions.first.answer_value
        form_page_path(@step.form_id, @step.form_slug, @step.goto_page_slug)
      else
        form_page_path(@step.form_id, @step.form_slug, @step.next_page_slug)
      end
    end

    def check_goto_page_before_routing_page
      return unless @step.routing_conditions.filter { |condition| condition.validation_errors.filter { |error| error.name == "cannot_have_goto_page_before_routing_page" }.any? }.any?

      EventLogger.log_page_event(current_context, @step, request, "goto_page_before_routing_page_error", nil)
      render template: "errors/goto_page_before_routing_page", locals: { link_url: "#{Settings.forms_admin.base_url}/forms/#{@step.form_id}/pages/#{@step.page_slug}/conditions/#{@step.routing_conditions.first.id}", question_number: @step.page_number }, status: :unprocessable_entity
    end
  end
end
