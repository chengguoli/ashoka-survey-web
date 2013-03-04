class ResponsesExcelJob < Struct.new(:survey, :response_ids, :organization_names, :user_names, :server_url, :filename)
  def perform
    package = Axlsx::Package.new do |p|
      wb = p.workbook
      bold_style = wb.styles.add_style sz: 12, b: true, alignment: { horizontal: :center }
      border = wb.styles.add_style border: { style: :thin, color: '000000' }
      questions = survey.first_level_elements.map(&:with_sub_questions_in_order).flatten
      wb.add_worksheet(name: "Responses") do |sheet|
        headers = questions.map { |question| "#{QuestionDecorator.find(question).question_number}) #{question.content}" }
        headers.unshift("Response No.")
        headers << "Added By" << "Organization" << "Last updated at" << "Address" << "IP Address"
        sheet.add_row headers, :style => bold_style
        responses = Response.where('responses.id in (?)', response_ids)
        responses.each_with_index do |response, i|
          response_answers =  Answer.where(:response_id => response[:id])
          .order('answers.record_id')
          .includes(:choices => :option).all
          answers_for_excel = questions.map do |question|
            question_answers = response_answers.find_all { |a| a.question_id == question.id }
            question_answers ? question_answers.map { |answer| answer.content_for_excel(server_url) }.join(', ') : ""
          end
          answers_for_excel.unshift(i+1)
          answers_for_excel << user_names[response[:user_id]]
          answers_for_excel << organization_names.find { |org| org.id == response[:organization_id] }.try(:name)
          answers_for_excel << response[:last_update]
          answers_for_excel << response[:location]
          answers_for_excel << response[:ip_address]
          sheet.add_row answers_for_excel, style: border
        end
      end
    end
    f = File.open(Rails.root.join('public', filename), 'w')
    package.serialize(f)
  end

  def error(job, exception)
    Airbrake.notify(exception)
  end
end