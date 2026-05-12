defmodule Background.JobBehaviour do
  @type prog_callback_t :: (term -> any) | nil
  @type job_result_t :: { :ok, term } | { :error, term }

  @callback prepare_as_job(path :: binary, job_data :: map()) ::
    { :ok, (prog_callback_t -> job_result_t), (-> any) } |
    { :ok, (prog_callback_t -> job_result_t) } |
    { :error, term }
end
