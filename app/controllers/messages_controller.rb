class MessagesController < GoogleApiController
  def index
    fetch_new_messages
    @messages = current_user.messages.undone.end_date_sorted
    render :index, status: :ok
    # render :json => current_user.messages.end_date_sorted

    # client = GooglePlaces::Client.new('AIzaSyDfgfZ73sBKMPhJONub1MNNvCo-l7crK2I')
    # render :json => client.predictions_by_input(
    #     'Allerm',
    #     types: 'geocode',
    #     lat: 53.5510846,
    #     lng: 9.993681899999956,
    #     radius: 70000 # fixed in gem
    # ).to_json
  end

  def show
    render :json => current_user.messages.find_by(id: params[:id])
  end

  def update
    @message = current_user.messages.find_by(message_id: params[:id])
    if @message.update!(message_params)
      render :status => :ok
    else
      render :status => :unprocessable_entity
    end
  end

  private

  def message_params
    params.require(:message).permit(:is_done)
  end

  def fetch_new_messages
    google_tokens = JSON.parse(current_user.google_tokens)
    client = Google::Apis::GmailV1::GmailService.new
    client.authorization = google_tokens['token']
    data = {q: 'subject: TNS - Einsatz Mystery Shopping Aldi  after:2017/11/01'}
    messages = client.list_user_messages('me', data)
    messages.messages.each do |m|
      message = Message.find_by(message_id: m.id.to_s)
      if message == nil
        fetch_new_message client, m
      end
    end
  end

  def fetch_new_message(client, m)
    message = JSON.parse(client.get_user_message('me', m.id).to_json)
    body = message['payload']['parts'][0]['parts'][0]['body']['data']
    body = base64_url_decode(body).force_encoding('UTF-8')

    address = Message.process_address_regex body
    times = Message.process_times_regex body

    body.gsub!(/[[:space:]]/, '')
    end_date = Message.process_end_data_regex body
    price = Message.process_price_regex body
    test_id = Message.process_test_id_regex body
    check_number = Message.process_check_number_regex body

    current_user.messages.create(
        message_id: m.id,
        adress: address,
        end_date: end_date,
        times: times.to_json,
        price: price,
        test_id: test_id,
        check_number: check_number
    )
  end

  def base64_url_decode(str)
    str += '=' * (4 - str.length.modulo(4))
    Base64.decode64(str.tr('-_','+/'))
  end
end
