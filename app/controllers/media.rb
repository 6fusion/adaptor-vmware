AdaptorVMware.controllers :media do
  before do
    logger.info('media#before')
    content_type 'application/json'
  end

  get :index do
    logger.info('GET - media#index')
    @medium = Medium.parse_ovf(params[:ovf_location])

    render 'media/show'
  end
end
