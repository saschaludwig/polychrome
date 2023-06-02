#pragma once
#include <JuceHeader.h>

#include <memory>

#include "error.h"
#include "processor.h"

using AudioGraphIOProcessor = juce::AudioProcessorGraph::AudioGraphIOProcessor;
using Node = juce::AudioProcessorGraph::Node;
using NodeID = juce::AudioProcessorGraph::NodeID;
using Connection = juce::AudioProcessorGraph::Connection;

class Engine : public juce::ChangeListener
{
 public:
  struct Config
  {
    explicit Config() :
      m_deviceName(m_defaultDevice),
      m_inputs(m_defaultInputs),
      m_outputs(m_defaultOutputs),
      m_sampleRate(m_defaultSampleRate)
    {
    }

    Config WithDeviceName(juce::String const &deviceName)
    {
      auto retval = *this;
      retval.m_deviceName = deviceName.isEmpty() ? m_defaultDevice : deviceName;
      return retval;
    }
    Config WithInputs(uint32_t inputs)
    {
      auto retval = *this;
      retval.m_inputs = inputs;
      return retval;
    }
    Config WithOutputs(uint32_t outputs)
    {
      auto retval = *this;
      retval.m_outputs = outputs;
      return retval;
    }
    Config WithSampleRate(uint32_t sampleRate)
    {
      auto retval = *this;
      retval.m_sampleRate = sampleRate == 0 ? m_defaultSampleRate : sampleRate;
      return retval;
    }
    juce::String deviceName() const { return m_deviceName; }
    uint32_t inputs() const { return m_inputs; }
    uint32_t outputs() const { return m_outputs; }
    uint32_t sampleRate() const { return m_sampleRate; }

   private:
    juce::String m_deviceName;
    uint32_t m_inputs;
    uint32_t m_outputs;
    uint32_t m_sampleRate;

   private:
    static constexpr const char *m_defaultDevice = "MacBook Pro Speakers";
    static constexpr uint32_t m_defaultInputs = 2;
    static constexpr uint32_t m_defaultOutputs = 2;
    static constexpr uint32_t m_defaultSampleRate = 44100;
  };

 public:
  Engine();

  ~Engine();

 public:
  [[nodiscard]] Error configure(Config const &config);
  [[nodiscard]] Error playSound(const juce::File &file, int channel);
  [[nodiscard]] Error playSound(std::unique_ptr<juce::PositionableAudioSource> src, int channel,
                                juce::String const &name);

 public:
  void changeListenerCallback(ChangeBroadcaster *source) override;

 private:
  [[nodiscard]] Error configureDeviceManager(Config const &config);
  [[nodiscard]] Error configureGraph(Config const &config);

 private:
  juce::AudioDeviceManager m_deviceManager;
  std::unique_ptr<juce::AudioProcessorGraph> m_mainProcessor;
  std::unique_ptr<juce::AudioProcessorPlayer> m_player;
  Node::Ptr audioOutputNode;
  std::mutex mut;

 private:
  JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Engine)
};
