defmodule Fset.DocsSample do
  use Fset.JSONSchema.Vocab

  @ex_1 "{\"$a\":\"feb3e92b-2349-4dc0-afec-a02eb45a4799\",\"fields\":[{\"$a\":\"074f4752-6832-4395-aafe-4c9ab903a08a\",\"key\":\"bounds\",\"m\":3,\"schs\":[{\"$a\":\"7a1836da-36ec-4a59-8363-ae959d8912aa\",\"m\":3,\"t\":29,\"v\":\"full\"},{\"$a\":\"c29c726b-9373-4fd1-9914-09cfd446e2ff\",\"m\":3,\"t\":29,\"v\":\"flush\"}],\"t\":15},{\"$a\":\"28e2e1f4-865f-4eb0-b19c-a640eef080f5\",\"key\":\"center\",\"m\":3,\"t\":26},{\"$a\":\"cc791fb4-89a2-4fde-a459-18653cfcd779\",\"key\":\"data\",\"m\":3,\"schs\":[{\"$a\":\"c5972d5f-3aad-4f60-85b7-f057e3ff1021\",\"$r\":\"3d1bd53b-2384-44ee-8122-51d22ec431d9\",\"m\":1,\"t\":28},{\"$a\":\"66b7d131-5e62-49ae-b1f6-477a36c57308\",\"m\":3,\"t\":27}],\"t\":15},{\"$a\":\"689bfc99-c919-40ca-88b4-2f456bb1eac2\",\"key\":\"description\",\"m\":3,\"t\":17},{\"$a\":\"19dbebef-50a3-44f7-9527-ffad95cda1a8\",\"key\":\"name\",\"m\":3,\"t\":17},{\"$a\":\"f965d62a-e228-4b3c-8935-59d6b82ae8db\",\"$r\":\"80326a68-f911-447e-8864-893835cb74cc\",\"key\":\"resolve\",\"m\":1,\"t\":28},{\"$a\":\"5815eeda-ae11-4916-a11e-812d55d09a7f\",\"key\":\"spacing\",\"m\":3,\"t\":25},{\"$a\":\"3ea4958c-a675-4bcf-a9ca-1c2d8f95adde\",\"key\":\"title\",\"m\":3,\"schs\":[{\"$a\":\"7ee3eb0b-56af-47fb-a824-66294f12dfbc\",\"$r\":\"058073c3-5dce-4e48-807e-953bb92bb8df\",\"m\":1,\"t\":28},{\"$a\":\"715568b3-3fd5-4e33-b4de-71e0e938fd43\",\"$r\":\"b1312d5f-96ce-4ebb-8db5-23b6c25b487c\",\"m\":1,\"t\":28}],\"t\":15},{\"$a\":\"0c82e067-ce39-4eef-8cc8-564968385317\",\"key\":\"transform\",\"m\":3,\"sch\":{\"$a\":\"79f551e2-068e-4176-a725-4b942546c1d9\",\"$r\":\"02d5de0d-c2e9-4c2e-bf8c-8ba57de18518\",\"m\":1,\"t\":28},\"t\":13},{\"$a\":\"ef836ef4-27d0-4828-b67e-a03f29a1eeee\",\"key\":\"vconcat\",\"m\":3,\"sch\":{\"$a\":\"e7fa81ee-8e90-4424-b245-2f36c9888c0c\",\"$r\":\"d7a009c5-f0f7-45d0-b413-13fd99b275f2\",\"m\":1,\"t\":28},\"t\":13}],\"index\":0,\"key\":\"VConcatSpec<GenericSpec>\",\"m\":3,\"t\":10,\"tag\":\"top_lv\"}"
  @ex_1_models "{\"3d1bd53b-2384-44ee-8122-51d22ec431d9\":{\"display\":\"D :: Data\"},\"80326a68-f911-447e-8864-893835cb74cc\":{\"display\":\"R :: Resolve\"},\"058073c3-5dce-4e48-807e-953bb92bb8df\":{\"display\":\"T :: Text\"},\"b1312d5f-96ce-4ebb-8db5-23b6c25b487c\":{\"display\":\"T :: TitleParams\"},\"02d5de0d-c2e9-4c2e-bf8c-8ba57de18518\":{\"display\":\"T :: Transform\"},\"d7a009c5-f0f7-45d0-b413-13fd99b275f2\":{\"display\":\"S :: Spec\"}}"

  defmacrop file_store(fmodels, models) do
    fmodels = Macro.expand(fmodels, __CALLER__) |> List.wrap()
    models = Macro.expand(models, __CALLER__)

    "{\"t\":10,\"fields\":[#{fmodels}],\"_models\":#{models},\"key\":\"\",\"taggedLevel\":{\"1\":\"name\"}}"
  end

  def types do
    %{
      ex_1: file_store(@ex_1, @ex_1_models),
      fmodels: Fset.Exports.JschDocs.gen("Fixtures")
    }
  end
end
