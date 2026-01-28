import React from 'react';

export interface TranscriptSegment {
  id: string;
  speaker: string;
  text: string;
  audio_start_time: number;
  audio_end_time: number;
  duration: number;
}

interface TranscriptViewProps {
  segments: TranscriptSegment[];
  onSegmentClick?: (audioStartTime: number) => void;
  currentPlaybackTime?: number;
}

const TranscriptView: React.FC<TranscriptViewProps> = ({
  segments,
  onSegmentClick,
  currentPlaybackTime = 0,
}) => {
  const formatTimestamp = (seconds: number): string => {
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  };

  const isSegmentActive = (segment: TranscriptSegment): boolean => {
    return (
      currentPlaybackTime >= segment.audio_start_time &&
      currentPlaybackTime < segment.audio_end_time
    );
  };

  return (
    <div className="space-y-4">
      {segments.map((segment) => {
        const isActive = isSegmentActive(segment);
        
        return (
          <div
            key={segment.id}
            className={`p-3 rounded-lg transition-colors ${
              isActive
                ? 'bg-blue-50 border-l-4 border-blue-500'
                : 'bg-gray-50 hover:bg-gray-100'
            }`}
          >
            <div className="flex items-start gap-3">
              <button
                onClick={() => onSegmentClick?.(segment.audio_start_time)}
                className="text-sm text-blue-600 hover:text-blue-800 cursor-pointer hover:underline font-mono min-w-[50px] text-left"
                title="Click to jump to this time"
                aria-label={`Jump to ${formatTimestamp(segment.audio_start_time)}`}
              >
                {formatTimestamp(segment.audio_start_time)}
              </button>
              
              <div className="flex-1">
                <span className="font-semibold text-gray-700">
                  {segment.speaker}:
                </span>
                <p className="text-gray-600 mt-1">{segment.text}</p>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export default TranscriptView;
