// Prismatic AI Agent Framework Documentation Search

class DocumentationSearch {
    constructor() {
        this.searchIndex = null;
        this.searchInput = null;
        this.searchResults = null;
        this.init();
    }

    init() {
        // Initialize search when DOM is ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.setupSearch());
        } else {
            this.setupSearch();
        }
    }

    setupSearch() {
        this.createSearchInterface();
        this.loadSearchIndex();
        this.bindEvents();
    }

    createSearchInterface() {
        // Create search container if it doesn't exist
        let searchContainer = document.querySelector('.search-container');
        if (!searchContainer) {
            searchContainer = document.createElement('div');
            searchContainer.className = 'search-container';
            searchContainer.innerHTML = `
                <div class="search-box">
                    <input type="text" id="search-input" placeholder="Search documentation..." />
                    <div id="search-results" class="search-results"></div>
                </div>
            `;
            
            // Insert after header
            const header = document.querySelector('.site-header');
            if (header) {
                header.insertAdjacentElement('afterend', searchContainer);
            }
        }

        this.searchInput = document.getElementById('search-input');
        this.searchResults = document.getElementById('search-results');
    }

    async loadSearchIndex() {
        try {
            // In a real implementation, this would load from a generated search index
            // For now, we'll create a simple in-memory index
            this.searchIndex = this.createSimpleIndex();
        } catch (error) {
            console.warn('Search index could not be loaded:', error);
        }
    }

    createSimpleIndex() {
        // Simple search index based on common documentation sections
        return [
            {
                title: 'Architecture Overview',
                url: '/architecture/',
                content: 'System architecture, design patterns, and core components',
                section: 'Architecture'
            },
            {
                title: 'Agent System',
                url: '/agents/',
                content: 'AI agents, memory systems, reasoning, and behavior patterns',
                section: 'Agents'
            },
            {
                title: 'Crisis Intervention',
                url: '/applications/crisis-intervention.md',
                content: 'Crisis negotiation, emergency response, and intervention protocols',
                section: 'Applications'
            },
            {
                title: 'Society Management',
                url: '/societies/',
                content: 'Multi-agent societies, group dynamics, and emergent behavior',
                section: 'Societies'
            },
            {
                title: 'Nabla-Infinity Framework',
                url: '/nabla-infinity/',
                content: 'Recursive introspection, consciousness emergence, and self-modeling',
                section: 'Advanced'
            },
            {
                title: 'Psychological Warfare',
                url: '/psychological-warfare/',
                content: 'Manipulation detection, countermeasures, and defensive systems',
                section: 'Security'
            },
            {
                title: 'Memory Systems',
                url: '/memory/',
                content: 'Multi-layered memory architecture and storage systems',
                section: 'Core Systems'
            },
            {
                title: 'Blackboard Communication',
                url: '/blackboard/',
                content: 'Distributed communication and message passing systems',
                section: 'Core Systems'
            },
            {
                title: 'Reasoning Engine',
                url: '/reasoning/',
                content: 'Formal reasoning, logic engines, and decision making',
                section: 'Core Systems'
            },
            {
                title: 'API Documentation',
                url: '/api/',
                content: 'REST API, GraphQL, authentication, and integration guides',
                section: 'Development'
            }
        ];
    }

    bindEvents() {
        if (!this.searchInput) return;

        let searchTimeout;
        this.searchInput.addEventListener('input', (e) => {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                this.performSearch(e.target.value);
            }, 300);
        });

        this.searchInput.addEventListener('focus', () => {
            this.searchResults.style.display = 'block';
        });

        // Hide results when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.search-container')) {
                this.searchResults.style.display = 'none';
            }
        });

        // Handle keyboard navigation
        this.searchInput.addEventListener('keydown', (e) => {
            this.handleKeyboardNavigation(e);
        });
    }

    performSearch(query) {
        if (!query.trim() || !this.searchIndex) {
            this.searchResults.innerHTML = '';
            this.searchResults.style.display = 'none';
            return;
        }

        const results = this.searchIndex.filter(item => {
            const searchText = `${item.title} ${item.content} ${item.section}`.toLowerCase();
            return searchText.includes(query.toLowerCase());
        });

        this.displayResults(results, query);
    }

    displayResults(results, query) {
        if (results.length === 0) {
            this.searchResults.innerHTML = `
                <div class="search-no-results">
                    <p>No results found for "${query}"</p>
                    <p class="search-suggestion">Try different keywords or browse the sections above.</p>
                </div>
            `;
        } else {
            const resultsHTML = results.map((result, index) => `
                <div class="search-result-item" data-index="${index}">
                    <h4><a href="${result.url}">${this.highlightQuery(result.title, query)}</a></h4>
                    <p class="search-result-section">${result.section}</p>
                    <p class="search-result-content">${this.highlightQuery(result.content, query)}</p>
                </div>
            `).join('');

            this.searchResults.innerHTML = resultsHTML;
        }

        this.searchResults.style.display = 'block';
    }

    highlightQuery(text, query) {
        if (!query.trim()) return text;
        
        const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi');
        return text.replace(regex, '<mark>$1</mark>');
    }

    handleKeyboardNavigation(e) {
        const items = this.searchResults.querySelectorAll('.search-result-item');
        if (items.length === 0) return;

        let currentIndex = -1;
        const current = this.searchResults.querySelector('.search-result-item.active');
        if (current) {
            currentIndex = parseInt(current.dataset.index);
        }

        switch (e.key) {
            case 'ArrowDown':
                e.preventDefault();
                currentIndex = Math.min(currentIndex + 1, items.length - 1);
                this.setActiveResult(items, currentIndex);
                break;
            case 'ArrowUp':
                e.preventDefault();
                currentIndex = Math.max(currentIndex - 1, 0);
                this.setActiveResult(items, currentIndex);
                break;
            case 'Enter':
                e.preventDefault();
                if (current) {
                    const link = current.querySelector('a');
                    if (link) link.click();
                }
                break;
            case 'Escape':
                this.searchResults.style.display = 'none';
                this.searchInput.blur();
                break;
        }
    }

    setActiveResult(items, index) {
        items.forEach(item => item.classList.remove('active'));
        if (items[index]) {
            items[index].classList.add('active');
            items[index].scrollIntoView({ block: 'nearest' });
        }
    }
}

// Add search styles
const searchStyles = `
<style>
.search-container {
    background-color: #f8f9fa;
    padding: 1rem 0;
    border-bottom: 1px solid #dee2e6;
}

.search-box {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 2rem;
    position: relative;
}

#search-input {
    width: 100%;
    max-width: 500px;
    padding: 0.75rem 1rem;
    border: 1px solid #ced4da;
    border-radius: 0.5rem;
    font-size: 1rem;
    outline: none;
    transition: border-color 0.2s ease;
}

#search-input:focus {
    border-color: #3498db;
    box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.1);
}

.search-results {
    position: absolute;
    top: 100%;
    left: 2rem;
    right: 2rem;
    max-width: 500px;
    background: white;
    border: 1px solid #dee2e6;
    border-radius: 0.5rem;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    max-height: 400px;
    overflow-y: auto;
    z-index: 1000;
    display: none;
}

.search-result-item {
    padding: 1rem;
    border-bottom: 1px solid #f1f3f4;
    cursor: pointer;
    transition: background-color 0.2s ease;
}

.search-result-item:last-child {
    border-bottom: none;
}

.search-result-item:hover,
.search-result-item.active {
    background-color: #f8f9fa;
}

.search-result-item h4 {
    margin: 0 0 0.25rem 0;
    font-size: 1rem;
}

.search-result-item h4 a {
    color: #3498db;
    text-decoration: none;
}

.search-result-section {
    font-size: 0.75rem;
    color: #6c757d;
    margin: 0 0 0.25rem 0;
    text-transform: uppercase;
    font-weight: 600;
}

.search-result-content {
    font-size: 0.875rem;
    color: #666;
    margin: 0;
    line-height: 1.4;
}

.search-no-results {
    padding: 2rem;
    text-align: center;
    color: #6c757d;
}

.search-suggestion {
    font-size: 0.875rem;
    margin-top: 0.5rem;
}

mark {
    background-color: #fff3cd;
    padding: 0.125rem 0.25rem;
    border-radius: 0.25rem;
}

@media (max-width: 768px) {
    .search-box {
        padding: 0 1rem;
    }
    
    .search-results {
        left: 1rem;
        right: 1rem;
        max-width: none;
    }
}
</style>
`;

// Inject styles
document.head.insertAdjacentHTML('beforeend', searchStyles);

// Initialize search when script loads
new DocumentationSearch();