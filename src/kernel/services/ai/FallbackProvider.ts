import { AIProvider, AIProviderConfig, AICompletionResponse } from './AIProvider.js';
import { logger } from '../../utils/logger.js';

/**
 * FallbackProvider removed - system now fails clearly if primary provider fails
 * No silent fallback to ollama
 */

export class FallbackProvider implements AIProvider {
  private primary: AIProvider;

  constructor(primary: AIProvider) {
    this.primary = primary;
  }

  async complete(
    prompt: string,
    systemPrompt?: string,
    config?: Partial<AIProviderConfig>
  ): Promise<AICompletionResponse> {
    // No fallback - just try primary and let it fail clearly
    return await this.primary.complete(prompt, systemPrompt, config);
  }

  async completeJSON<T>(prompt: string, systemPrompt?: string): Promise<T> {
    const response = await this.complete(prompt, systemPrompt);
    const jsonMatch = response.content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]) as T;
    }
    throw new Error('No JSON found in response');
  }

  getModel(): string {
    return this.primary.getModel();
  }

  getProvider(): string {
    return this.primary.getProvider();
  }
}
