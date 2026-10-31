import { useContext } from 'react'
import { useTranslation } from 'react-i18next'
import { ToggleSwitch } from 'frontend/components/UI'
import useSetting from 'frontend/hooks/useSetting'
import SettingsContext from '../SettingsContext'
import InfoIcon from 'frontend/components/UI/InfoIcon'

/**
 * Liga o sync de saves em todos os jogos de uma vez.
 *
 * `autoSyncSaves` sempre existiu como padrao global, mas so era exposto dentro
 * do Settings de cada jogo, entao ligar em todos exigia abrir jogo por jogo.
 */
const AutoSyncSaves = () => {
  const { t } = useTranslation()
  const { isDefault } = useContext(SettingsContext)
  const [autoSyncSaves, setAutoSyncSaves] = useSetting('autoSyncSaves', false)

  if (!isDefault) {
    return <></>
  }

  return (
    <div className="toggleRow">
      <ToggleSwitch
        htmlId="autoSyncSaves"
        value={autoSyncSaves}
        handleChange={() => setAutoSyncSaves(!autoSyncSaves)}
        title={t(
          'setting.autoSyncSavesAll',
          'Synchronize saves automatically for all games'
        )}
      />
      <InfoIcon
        text={t(
          'help.autoSyncSavesAll',
          'Downloads the cloud save before launching and uploads the local save on exit. Games without a save path yet have it detected on the first launch. Individual games can still override this.'
        )}
      />
    </div>
  )
}

export default AutoSyncSaves
